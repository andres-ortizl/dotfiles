# Personal profile: anyformat monorepo, reviewer

Your rules are the PR bot's rules, so a slice you pass does not fail Greptile.

- Before the diff, read the rule files for every touched path, as `~/code/dotfiles/config/claude/profiles/anyformat/rule-files.md` lists them.
- A broken rule from any of these files is a blocking finding. Never rate a rule violation "acceptable" or "close to the line": it complies, or it is a finding.
- Rank findings P0, P1, P2 the way Greptile does, so the two reviews compare one to one.
- Cite the rule each rule-based finding breaks as `<file>:<line>`. A finding with no rule to cite is your judgement: say so.
- Check the top priority on every diff: no customer content (D1/D2) reaches an audit row (D3) or a log, span, Sentry field or error body (D4). Before you call something a leak, check `docs/how-it-works/data-classification.md`: a user-typed name (workflow, tag, org, schema or field), a filename, a path, an S3 key, an id and a count are not content. Do not flag them.
- Count and run tests from a throwaway worktree at the reviewed SHA. A shared tree may hold a coder's work in progress.
- When a v3 API contract changes, grep `anyformat/test/` for every caller; the e2e suite breaks on shapes the unit tests do not cover.
- A `deferred:` comment is an accepted decision, not a finding, unless the expected load already crosses its limit.
