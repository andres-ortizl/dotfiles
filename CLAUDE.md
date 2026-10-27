# dotfiles

- This repository uses direct commits to `master`. Do not create a feature branch or pull request unless the user explicitly asks for one.
- When the user asks to push changes, validate them, rebase onto `origin/master` if needed, then push `master` directly.
- The pre-commit hooks check the whole tree, not only staged files. A failure in a file you did not touch is pre-existing: report it, do not fix it unasked.
