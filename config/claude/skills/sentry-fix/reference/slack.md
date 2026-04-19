# Slack `#tech` message templates

## Slack proxy-error fallback

`mcp__claude_ai_Slack__slack_send_message` occasionally returns `Anthropic Proxy: Invalid content from server` on messages with heavy markdown (nested blockquotes + multiple URLs + emoji). When this happens, retry once with a plainer format: single line, no blockquotes, URLs inline with space separators. Do NOT abandon the notification — the user depends on it as the run's scoreboard.

## `#tech` channel filter (strict — low-noise mode)

The `#tech` channel is for *advertisement*, not per-issue detail. A whole sentry-fix cycle produces **two** channel messages, plus `:white_check_mark:` resolves on merge. Everything else (per-issue root cause, gated-issue rationale, reviewer findings, CI retries, Greptile rounds, coder status) lives on the GH issue dashboard and in personal DMs.

## Message 1 — Cycle started

Posted once at the beginning of the run, right after Stage A triage completes and the dispatch decisions are made. Single compact message:

```
:rocket: *[sentry-fix]* New review cycle started
>*Triaged:* N unresolved Sentry issues (M clusters)
>*Auto-dispatching:* K (will post back when PRs are up)
>*Gated for human approval:* G — details on GH dashboard
>*Pre-resolved from changelog:* P
>*Dashboard:* <GH milestone / issue-filter URL>
```

That's it — no per-issue breakdown in the channel. The dashboard link does the heavy lifting.

## Message 2 — PRs ready + reviewer raffle

Posted once when all dispatched spec loops have produced PRs that are Greptile 5/5 + CI green. Single compact channel message that lists each PR with its own tagged reviewer.

**Tone: light and playful**, not corporate. This is a raffle announcement — "the wheel of review has spoken" / "the Court of Greptile has blessed" / etc. A dry bureaucratic list gets ignored; a small joke earns eyeballs. The per-PR line should include a one-sentence plain-English blurb of what the fix does (not the Sentry error code prose from the plan — something a human reads in 2 seconds and chuckles at).

Template:

```
:game_die: *[sentry-fix]* The wheel of review has spoken — N Sentry fixes beg for eyeballs

<one-line flavor, e.g. "The roulette was fair and unbiased. The results are final. Allegedly.">

>:<emoji>: <https://github.com/<owner>/<repo>/pull/NNNN|*#NNNN*> — `<commit title>` → <@slack-id>
>  _<one-line plain-English blurb of what the fix does, italicized>_

>:<emoji>: <https://github.com/<owner>/<repo>/pull/NNNN|*#NNNN*> — `<commit title>` → <@slack-id>
>  _<blurb>_

>:<emoji>: <https://github.com/<owner>/<repo>/pull/NNNN|*#NNNN*> — `<commit title>` → <@slack-id>
>  _<blurb>_

All <N>: Greptile 5/5, CI green, tagged `sentry`, ready to merge. <one-line closer, e.g. "Your move, nominated ones. :saluting_face:">
```

Emoji picks per PR should vaguely match the fix area (`:moneybag:` for billing, `:file_folder:` for file storage, `:mag:` for search, `:lock:` for auth, etc.) — this is cosmetic but makes the message skimmable.

**PR references MUST be full Slack-link URLs**, not bare `#NNNN`. Slack does not auto-linkify GitHub PR numbers — `*#3131*` renders as bold text, not a link, and the reviewer has to copy-paste the number into a search bar to find the PR. Use the `<URL|display>` Slack link syntax so the bolded short form is clickable:

```
<https://github.com/anyformat-ai/anyformat-monorepo/pull/3131|*#3131*>
```

This renders as a bold `#3131` that links directly to the PR. Same for the gated-issue list at the bottom.

If there are gated (human-decision) issues, add one final line:
```
>*Gated (need human decision):* <#NNNN> · <#NNNN>  — see dashboard
```

If some PRs are still green but others are stuck, post this message for the green ones and leave the stuck ones in the dashboard (they'll come through on the next cycle's message-2 when they land, or as a gated-issue follow-up).

## Message 3 — Resolved on merge (one per merge, low-volume)

When a `sentry-fix/<id>` branch merges to `dev`:

```
:white_check_mark: *[sentry-fix]* Resolved — <title>
>*Sentry:* <issue URL>    *PR:* <merged PR URL>
```

This stays per-merge because it's celebratory and low-volume (3–5 per cycle, spread over hours as PRs trickle through review).

## What does NOT go to `#tech`

- ❌ Per-issue root-cause / proposed-fix rationale — **dashboard only**
- ❌ Per-gated-issue reasoning — **dashboard only**
- ❌ "Needs attention" DMs with multi-line details — **dashboard only**
- ❌ CI retries, Greptile rounds, coder status — **personal DM to user only**
- ❌ Progress pings — **personal DM to user only**

## Gated-issue details live on the GH dashboard

Every sentry-fix cycle creates/updates a pinned GH issue filter or milestone called `sentry-fix cycle YYYY-MM-DD`. Each gated issue gets its own GH issue with the full root-cause / proposed-fix / why-gated body (same content that used to be DMed to `#tech`). The channel message links to the dashboard filter and stops there — anyone who wants detail clicks through.

## Batch flow (end of run)

There is no "batch summary" message — the two `#tech` announcements (Message 1 at the top and Message 2 once the PRs land) are the whole advertisement. The channel stays quiet between them.

Flow:

1. **After Stage A triage + Stage B dispatch decisions**: create/update the GH dashboard (milestone + issues), post Message 1 (`:rocket: New cycle started`) to `#tech`. This is the only `#tech` post during active work.
2. **Stage B is running**: spec sub-sessions DM the user directly at each milestone. `#tech` is silent.
3. **When all dispatched PRs hit Greptile 5/5 + CI green**: run the reviewer raffle once, post Message 2 (`:game_die: Cycle complete`) to `#tech` with the tagged reviewer and PR links.
4. **As PRs merge**: Stage -1 of the NEXT run posts Message 3 (`:white_check_mark: Resolved`) per merge.

Schedule a wakeup in ~20 min to check whether the dispatched PRs have all reached 5/5 yet; when they have, post Message 2. If some are still under review, keep waking until either they're green or 2 hours have passed, at which point post Message 2 for whichever PRs are ready and mark the rest `blocked` on the GH dashboard (no extra `#tech` noise).
