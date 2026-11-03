# Pack: worktrees

Trigger: the session is isolated in a worktree, or two slices commit while both are active.
Last used: code-node-rename-and-costs

- Every coder and reviewer brief carries the worktree block: the absolute worktree path, that the repo's setup step is done there, one plain command per call, and multi-step scripts written as files in the scratchpad with an explicit chdir. A test wrapper takes the worktree path as an argument.
- Every slice that commits while another slice is active gets its own worktree. Two slices in one checkout clash on the index, the pre-commit stashes and whole-tree hooks.
- From a session isolated in a worktree, do not launch `slices-wave` with `isolation: worktree`: the guard refuses git to the fix-round agents. Run the slices serially in the session's worktree.
- To commit to a lower branch while a coder works in the same worktree, build the commit from blobs with a temporary `GIT_INDEX_FILE` and `git commit-tree`, so the coder's index is never touched.
