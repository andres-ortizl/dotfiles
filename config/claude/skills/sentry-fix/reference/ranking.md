# Ranking & gating

Sort the triage reports by:
1. `confidence=High` first
2. Then `scope=Small` first
3. Then by Sentry event frequency (desc)
4. Then by first-seen (older = higher priority)

Pick **top 3**. Everything else queues for the next run — this run does NOT continue past 3.

For each of the top 3, apply the gate:

| confidence | scope | action |
|---|---|---|
| High | Small | **Auto-dispatch** spec loop with `--auto-approve` |
| High | Medium | **DM `#tech`** for approval before dispatch |
| High | Large | **DM `#tech`** for approval; default is skip |
| Medium | any | **DM `#tech`** for approval |
| Low | any | **DM `#tech`** as `:rotating_light:` needs-intervention and skip |

`is_our_bug: false` → skip entirely, DM `#tech` with a single line explaining why.

## Gated issues land as GH issues, NOT as `#tech` DMs

Every gated issue gets its own GH issue in the current cycle's milestone / filter. The GH issue body IS the detailed writeup that previously went to `#tech`:

```markdown
## Sentry
<issue URL> — <short id> · <event count> events · <env>

## Confidence / Scope
<H|M|L> / <S|M|L>

## Root cause
<paragraph>

## Proposed fix
<paragraph>

## Why gated
<low confidence | too large | not-our-bug | architectural call needed | ...>

## Triage notes
<anything unusual from the Explore agent report>
```

Labels: `sentry-triage`, `bug`, `Backend` / `Core`, plus `needs-human-decision` on gated ones.

The `#tech` "cycle complete" message links to this dashboard. It does NOT list gated-issue details inline — that's what the dashboard is for.

Do NOT wait for a response synchronously. The loop continues with whatever auto-dispatchable issues remain. If 0 of K are auto-dispatchable, post the "cycle started" message, create GH issues for the gated ones, and stop — the reviewer-raffle message is only sent when at least one PR is actually ready.
