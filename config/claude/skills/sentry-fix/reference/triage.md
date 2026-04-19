# Stage A: Triage (parallel, read-only)

1. **Fetch all unresolved issues** for each configured project:
   ```bash
   curl -s "https://sentry.io/api/0/projects/$SENTRY_ORG/$project/issues/?query=is:unresolved&sort=freq&limit=100" \
     -H "Authorization: Bearer $SENTRY_AUTH_TOKEN"
   ```
   Union all results into a flat list of issues.

2. **Cluster duplicates before triaging.** Group issues whose `title` is identical OR whose top in-app stack frame is the same file+function. Past runs saw multiple Sentry IDs for the same root cause (e.g. `CORE-14N` + `CORE-1CH` — both `LengthFinishReasonError`; `CORE-1DM` + `CORE-1DK` — both `MONO/MULTI` BinderException; `CORE-1D7` + `1DA` + `1D9` — identical title). Triage the cluster representative, then reference every member ID in the plan + commit message so all get resolved on merge.

3. **Cap the triage fan-out.** Do NOT spawn 31 Explore agents at once — it eats 10k+ tokens in returned reports and most of the tail is low-value. Take the top **10** clusters sorted by `event_count desc, severity desc`. Everything below that queues for the next re-run.

4. **Pre-fetch each candidate's latest event** so agents get real stack traces instead of guessing:
   ```bash
   curl -s "https://sentry.io/api/0/organizations/$SENTRY_ORG/issues/$id/events/latest/" \
     -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" > /tmp/sentry_events/$id.json
   ```
   Then extract a compact summary (title, env, top 6 in-app frames per exception, error value truncated to 300 chars) with a small Python snippet, so each triage agent's brief fits in ~2k tokens.

5. **Spawn one Explore agent per cluster** — all in parallel in a single message with multiple `Agent` tool calls. Brief each agent with:
   - Cluster representative's Sentry issue title, message, stacktrace, event frequency, first seen, last seen
   - All duplicate issue IDs in the cluster
   - Reference to the repo root
   - Request a structured report:
     ```yaml
     sentry_issue_id: <cluster representative id>
     duplicate_ids: [<other ids in cluster>]
     title: <short description>
     root_cause: <one paragraph>
     proposed_fix: <one paragraph>
     files_to_touch: [...]
     scope: S | M | L
     confidence: High | Medium | Low
     reasoning: <why this confidence>
     is_our_bug: true | false
     notes: <anything that needs human attention>
     ```
   - Tell each agent: "Under 400 words. Read only, do not modify."

6. **Collect reports**. Any agent that returns `is_our_bug: false` or `confidence: Low` is flagged for skip/DM (see `ranking.md` gating).
