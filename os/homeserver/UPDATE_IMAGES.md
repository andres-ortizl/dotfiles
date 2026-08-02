# Homeserver image updates

Use `scripts/manage.sh` for every operational step. Read `AGENTS.md`, `docker-compose.yml`, and a live mode-600 lock captured with `scripts/manage.sh lock-images --output FILE` before editing anything.

Update one service at a time. Treat the selected service's `repo_digest` record in the live lock as the source of truth for its prior immutable digest; do not infer it from a tag. Use the same release channel and compare the current version with official release notes and upstream image metadata. Pin the exact intended digest in Compose. Never guess a digest. Floating tags are not an acceptable final state.

Preserve all volumes, bind mounts, storage paths, databases, networks, ports, capabilities, and unrelated services. Do not perform bulk upgrades. Do not add Watchtower or another automatic updater.

Run `scripts/manage.sh check`, use the pre-deploy lock as the rollback backup, then `scripts/manage.sh deploy SERVICE`. Verify the same channel, relevant release notes, service tests, and manual QA through the service's real user-facing surface. These gates must pass before any commit or push. If validation, tests, health, or manual QA fails, run `scripts/manage.sh rollback SERVICE IMAGE_REF@sha256:DIGEST` with the prior lock digest and verify recovery.

Do not print secrets, container environments, logs containing credentials, or full inspect output. Never run `docker compose down -v`, any prune command, force-push, or destructive storage operation.

After successful verification, create one atomic commit for that service. Push normally to `origin master` only after all gates pass; never force-push. After operator confirmation and evidence, run `scripts/manage.sh prune-images --yes`. Never prune before confirmation or use any volume, build, network, or container prune.
