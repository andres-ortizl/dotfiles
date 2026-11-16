# Pack: stacked PRs

Trigger: two or more slices whose PRs build on each other.
Last used: page-owns-its-blocks

- After the PRs exist, run `gh stack link --base <trunk> <every PR, merged ones included>`. GitHub then rebases and retargets the upper PRs when a lower one merges. If the repository has stacks disabled, merge bottom-up and retarget each child yourself.
- Open every PR ready for review, never as a draft, and link the stack as soon as the PRs exist.
- Merge with `gh stack merge <top-pr>` once every PR is clean. A merge stops at the first PR whose checks are not green; after a lower PR merges, the next one's checks restart on its rebased head.
- A fix round on a lower PR lands before the upper slice starts or resumes when they share files; the upper slice then rebases once (`git rebase --onto <new-base> <old-base-tip>`).
