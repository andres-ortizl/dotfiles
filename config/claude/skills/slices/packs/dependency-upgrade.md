# Pack: dependency upgrade

Trigger: a slice changes a lock file.
Last used: deps-stack-refresh-2026-11

- Build the package list from the resolver's dry-run, never from memory. The recipe excludes every package the plan puts out of scope, and resolves with a 7-day minimum release age. An AC greps each excluded package in the lock.
- After the lock changes, sync the venv and rebuild every image before any test. A suite run on a stale image proves nothing.
- ACs build every production image as CI does, including its build-time steps, and run every suite that imports a changed package.
