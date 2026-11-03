# Pack: rename

Trigger: a slice removes or renames a name or a value across the tree.
Last used: code-node-rename-and-costs

- The acceptance criterion greps every spelling: snake, camel, kebab, Pascal and the spaced product label. It excludes only documents that must name the old value to explain the change, such as a changelog or a migration test.
- It also runs every repo-wide check that indexes paths or names (decision-record path lists, inventories, link checks), not only the service suites.
- Merge trunk right before the review and again right before the push: a change across the whole tree collides with everything that lands meanwhile.
