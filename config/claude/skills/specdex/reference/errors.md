# Error Handling / Intervention Required

When anything needs user intervention, including:

- Errors (test suite broken, git conflict, API error)
- Permission prompts blocking a teammate (e.g., `cd && git` compound commands, unknown tools)
- Coder can't resolve review feedback after retries
- Ambiguous requirements the plan didn't clarify
- Any "Do you want to proceed?" prompt that blocks the autonomous flow

**Notify the user immediately (via `$NOTIFIER` — see Configuration; never hardcode Slack), with full context, and `dex block "<why>"`:**

```
:rotating_light: *[<spec name>]* Blocked — <what happened>
>*Phase:* <current phase>
>*Reason:* <why it can't continue>
>*Resume:* reattach via your multiplexer (zellij attach / tmux attach) <session-name>
```

Then:

1. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
2. Stop the loop and wait for the user to come back

## The intervention DM must always include

- **What** went wrong (one line)
- **Phase** it's stuck in (implementing, reviewing, shipping, greptile)
- **Why** it can't continue without the user
- **Resume command** (your multiplexer's attach — `zellij attach` / `tmux attach` `<session-name>`) so the user can jump straight in

## Rules

- Do NOT retry blindly.
- Do NOT use destructive git operations to work around issues.
