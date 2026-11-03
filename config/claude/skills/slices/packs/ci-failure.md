# Pack: CI failure

Trigger: a check fails on a slice's PR.
Last used: code-node-rename-and-costs

- Fetch only that job's log to a scratchpad file and `grep` it for the failing test names; never read a whole CI log into context.
- A job killed by a timeout prints no per-test reason: check whether other branches fail the same tests in the same window before blaming the slice.
