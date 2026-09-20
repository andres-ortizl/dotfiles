# Homeserver image updates

## Automatic updates

Dockhand updates application images within their configured moving tags. Use verified upstream stable channels or version-family tags. Keep Traefik on `v3.5` and Forgejo on `12` until their separate migration reviews; a moving tag does not advance to another release family.

Keep `immich-server`, `immich-machine-learning`, `redis`, and `database` pinned to exact digests with `dockhand.update=false`. Review and update these services manually. Keep the Immich server and machine-learning versions aligned.

After deploying the Compose changes, enable update checks and automatic updates in Dockhand under **Settings > Environments > the local environment > Updates**. Set the schedule to 04:00 in `Europe/Madrid`. Configure a notification channel and enable update-failure alerts. These settings persist in `./data/dockhand`; include that directory in backups. Do not add another updater.

## Manual deployments and recovery

Use `scripts/manage.sh` for operational steps. Before deployment, run `scripts/manage.sh check` and capture a mode-600 lock outside Git with `scripts/manage.sh lock-images --output FILE`. The lock records the immutable digest of each running image, even when its configured tag has moved.

Use `scripts/manage.sh deploy SERVICE` for one service or `scripts/manage.sh deploy all` for an operator-approved stack deployment. Preserve all volumes, bind mounts, storage paths, databases, networks, ports, capabilities, and unrelated configuration.

For a manually managed service, compare official release notes and upstream image metadata before changing its digest. Never guess a digest. Verify health, relevant tests, and the real user-facing application after deployment. A running container is not sufficient proof of success.

If an update fails, pause automatic updates for the affected service before recovery. Use `scripts/manage.sh rollback SERVICE IMAGE_REF@sha256:DIGEST` with the prior lock digest and verify recovery. Image rollback does not reverse database migrations; those can require a data backup.

Do not print secrets, container environments, logs containing credentials, or full inspect output. Never run `docker compose down -v`, force-push, or destructive storage operations. Never prune before operator confirmation. After confirmation and verification, only `scripts/manage.sh prune-images --yes` is allowed. Do not prune volumes, builds, networks, or containers.
