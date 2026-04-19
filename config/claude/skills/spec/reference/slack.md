# Slack DM Protocol

**Every milestone MUST send a Slack DM. This is not optional.** The user relies on these notifications to track progress without watching the terminal.

## Message format

All messages use Slack markdown and emojis for scannability:

```
<emoji> *[<spec name>]* <status> — <description>
```

## Emoji per milestone

- `:rocket:` — Spec started
- `:hammer_and_wrench:` — Implementation started
- `:white_check_mark:` — Implementation complete / tests passing
- `:mag:` — Review in progress
- `:tada:` — Review passed
- `:link:` — PR created
- `:robot_face:` — Greptile round verdict arrived
- `:wrench:` — CI / Greptile fix pushed
- `:trophy:` — Feature complete
- `:rotating_light:` — Blocked / needs intervention
- `:broom:` — Accepted / cleaned up

## Examples

- `:rocket: *[Snake Game]* Spec started — setting up workspace`
- `:hammer_and_wrench: *[Snake Game]* Implementation started — you can detach now (\`Ctrl+O, D\`). Next DM when tests pass.`
- `:white_check_mark: *[Snake Game]* Implementation complete — tests passing, moving to review`
- `:tada: *[Snake Game]* Review passed — shipping PR`
- `:link: *[Snake Game]* PR created — <https://github.com/org/repo/pull/123|#123>, waiting for Greptile`
- `:robot_face: *[Snake Game]* Greptile round 1 — score 3/5, fixing issues`
- `:trophy: *[Snake Game]* Complete — PR ready for human review: <https://github.com/org/repo/pull/123|#123>`
- `:rotating_light: *[Snake Game]* Blocked — test suite failing after 3 review rounds\n>*Phase:* review\n>*Reason:* reviewer found race condition in auth handler that coder can't resolve\n>*Resume:* \`zellij attach spec-snake-game\``

## Tool call

```
mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message="[<spec name>] <status> — <description>")
```

## Milestones that require a DM

- Spec started
- Implementation started (you can detach now)
- Implementation complete, tests passing
- Review passed (or failed after 3 rounds)
- PR created
- CI fix pushed (one DM per push, not per poll)
- Each Greptile round verdict arrived (`:robot_face:`)
- Each Greptile round fix pushed (`:wrench:`)
- Feature complete
- User intervention required (any error — see `errors.md`)
- Accepted (cleanup done)

## Greptile round DMs (two per round)

Every Greptile iteration MUST produce a Slack DM — no silent rounds. Send at TWO moments per round:

**(a) When Greptile's verdict arrives** (the moment you read the new summary + score):
```
:robot_face: *[<spec name>]* Greptile round N — score X/5
>*Findings:* <brief list, e.g. "2 P1, 1 P2" or "no issues">
>*Next:* <fixing in branch | merging>
```

**(b) When you push the fixup commit** for that round (the moment the new SHA is on the remote):
```
:wrench: *[<spec name>]* Greptile round N fixes pushed — <sha>
>*Changed:* <one-line summary of what was fixed>
>*Re-triggering Greptile for round N+1*
```

Both DMs are required. If a round has no findings (score 5/5 on first pass), send only the (a) DM and then the final `:trophy:` DM. If a round fails to produce a fix (e.g. coder blocked), send the (a) DM then escalate with the blocked DM from `errors.md`.

## Final DM (score 5/5)

```
:trophy: *[<spec name>]* Complete — PR ready for human review: <PR URL>
```

Log each DM in `~/.spec/<project-name>/<spec-name>/logbook.md`.
