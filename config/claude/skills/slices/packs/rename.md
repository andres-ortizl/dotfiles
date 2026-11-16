# Pack: rename

Trigger: a slice removes or renames a name or a value across the tree.
Last used: deps-stack-refresh-2026-11

- The acceptance criterion greps every spelling (snake, camel, kebab, Pascal, the spaced product label) with `-w`, plus the old owner's name for comments that point at it. Never filter its output with a second pattern; a check of imports parses the imports.
- Its pathspec excludes records that must keep the old name: accepted decision-record bodies, changelogs, and any dated or commit-pinned line. The brief says those keep the old name; only live docs get the new one.
- It also runs every repo-wide check that indexes paths or names (decision-record path lists, inventories, link checks), not only the service suites.
- Merge trunk right before the review and again right before the push, and re-run the acceptance greps on the merged tree: trunk adds old names in files that merge without a conflict.
