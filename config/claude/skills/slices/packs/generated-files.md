# Pack: generated files

Trigger: a slice regenerates a committed file (an API spec, a client, a type file, a catalog).
Last used: deps-stack-refresh-2026-11

- Drift checks that compare the working tree with the git index (`--check` modes, generated-client checks) pass only once the regenerated files are staged. Stage them, run the checks, then commit.
