# `dex` CLI — complete reference

`dex` is the spec event substrate. **One operation: record an event; state is derived.**
Resource-verb grammar, git/gh style.

## Target spec (ambient)

Every spec-scoped command needs a target spec — `<project>/<spec-name>`. Set it once:

```bash
export DEX_SPEC=anyformat-backend/parse-cache   # or pass -s <project>/<name> per call
```

`ls`, `watch`, `config`, and `install` are global — they ignore `DEX_SPEC`.

## Lifecycle / state

| Command | Effect |
|---|---|
| `dex init --branch <b> --worktree <path> [--collaborative]` | register the worktree (emits `spec.created`); `--collaborative` marks a human-driven session (badged apart from autonomous minions) |
| `dex phase <name> [--reason <why>]` | set lifecycle phase: `setup` `plan` `build` `review` `ship` `verify` `complete` `accepted` |
| `dex block "<reason>"` | flag the spec as blocked on the human (health → `needs-you`) |
| `dex unblock` | clear the blocked flag |
| `dex beat` | liveness heartbeat (phase read from state — don't repeat it) |

## Agents

| Command | Effect |
|---|---|
| `dex agent spawn <role> [--id <id>]` | a teammate started working (`role`: `coder` `reviewer` `lead`) |
| `dex agent idle <role>` | a teammate went idle |

## Observations

| Command | Effect |
|---|---|
| `dex test --passed <P> --failed <F> [--cmd "<cmd>"]` | record a test run |
| `dex review --round <N> --verdict <pass\|fail\|notes> [--blockers <b>] [--issues <i>]` | reviewer verdict |
| `dex gate --provider <ci\|review> [--name <check>] --result <result> [--score <0-5>]` | a PR gate landed (`result`: `success` `failure` `cancelled` `skipped` `timed_out` `neutral` `pending`) |
| `dex pr --number <N> --url <url> [--state open\|merged\|closed]` | record the PR (state defaults to `open`; flip to `merged`/`closed` when the host reports it) |
| `dex note --level <info\|warn\|error> --topic <topic> --text "<observation>"` | freeform signal (the curator/watcher feed) |

`ci` and `review` are **roles**, not vendors — config maps them to a tool.

## Ports

| Command | Effect |
|---|---|
| `dex ports alloc` | pick a free, collision-aware port offset from `[[ports]]` config; records it and prints `export <ENV>=<port>` lines. Use `eval "$(dex ports alloc)"` |

## Fleet (global)

| Command | Effect |
|---|---|
| `dex ls` | table of every spec with derived health (`alive` `idle` `stale` `needs-you` `done`) |
| `dex watch` | stream the fleet snapshot as JSON, re-emitting on every registry change |

## Config (global)

| Command | Effect |
|---|---|
| `dex config init [--force]` | write a commented `.dex.toml` template to the current dir (the deterministic way to create config — edit it after) |
| `dex config show` | merged effective config as JSON (`defaults ← ~/.config/dex/config.toml ← .dex.toml`) |
| `dex config get <dotted.key>` | one value — e.g. `providers.notifier`, `providers.multiplexer`, `providers.pr_review.reactor`, `hooks.on_ship`, `phases_skip`, `models.coder`, `ports`, `identity.github_org` |
| `dex config validate` | typed validation; warns on referenced reactor/hook skills not in `~/.claude/skills` |
| `dex config schema` | machine-readable option space (valid providers per role, hook points, phases, models, ports shape) |

## Install (global)

| Command | Effect |
|---|---|
| `dex install` | copy the `/specdex` skill + `dex-*` agents into `~/.claude`, scaffold `~/.config/dex/config.toml`. Won't clobber an existing skill |
| `dex install --update` | same, but overwrite the skill (re-sync after changes) |

## Notes

- Enum args (`phase`, `role`, `verdict`, gate `provider`/`result`, `note` level, `model`) are validated — an unknown value errors before anything is written.
- Records live at `~/.spec/<project>/<spec>/` — append-only `events.jsonl` (source of truth) + derived `state.json`.
