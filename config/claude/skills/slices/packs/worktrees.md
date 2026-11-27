# Pack: worktrees

Trigger: the session is isolated in a worktree, or two slices commit while both are active.
Last used: deps-stack-refresh-2026-11

- Every coder and reviewer brief carries the worktree block: the absolute worktree path, that the repo's setup step is done there, one plain command per call, and multi-step scripts written as files in the scratchpad with an explicit chdir. A test wrapper takes the worktree path as an argument.
- MCP tools a subagent inherits point at the server the session started with, never at its worktree's stack. A brief that needs a local server names the worktree's own way to reach it (a CLI call over the worktree's port).
- Every slice in a wave of two or more gets its own worktree, and `slices-wave` refuses a wave that misses one. Two slices in one checkout clash on the index, the pre-commit stashes and whole-tree hooks.
- From a session isolated in a worktree, do not launch `slices-wave` with `isolation: worktree`: the guard refuses git to the fix-round agents. Run the slices serially in the session's worktree.
- To commit to a lower branch while a coder works in the same worktree, build the commit from blobs with a temporary `GIT_INDEX_FILE` and `git commit-tree`, so the coder's index is never touched.
