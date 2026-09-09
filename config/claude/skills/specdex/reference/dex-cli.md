# `dex` CLI — complete reference

`dex` is the spec event substrate. **One operation: record an event; state is derived.**
Resource-verb grammar, git/gh style.

## Target spec

Every spec-scoped command needs a target spec — `<project>/<spec-name>` — and an actor. **Pass both as flags on every call:**

```bash
dex -s <project>/<spec-name> --actor lead <verb> ...     # or --actor coder | reviewer
```

Do **not** rely on `export DEX_SPEC` / `DEX_ACTOR`. A teammate is a separate session whose shell does not persist environment between commands, and some repos' command verifiers reject `VAR=value dex ...` prefixes outright. Either way the call runs with no target and the event is lost silently — and a spec with no events is invisible to `resume`, to the fleet view, and to `dex story next`. The flags are two extra words and they never fail.

`ls`, `watch`, `config`, and `install` are global — they need no spec.

## Lifecycle / state

| Command | Effect |
|---|---|
| `dex init --branch <b> --worktree <path> [--session <id>] [--collaborative]` | register the worktree (emits `spec.created`); `--session` records the Claude Code session id so `resume` can find the originating session — pass `$CLAUDE_CODE_SESSION_ID`, and omitting it costs resume its pointer; `--collaborative` marks a human-driven session (badged apart from autonomous minions) |
| `dex phase <name> [--reason <why>]` | set lifecycle phase: `setup` `plan` `build` `review` `ship` `verify` `complete` `accepted` |
| `dex block "<reason>"` | flag the spec as blocked on the human (health → `needs-you`) |
| `dex unblock` | clear the blocked flag |
| `dex beat` | liveness heartbeat (phase read from state — don't repeat it) |

## Agents

| Command | Effect |
|---|---|
| `dex agent spawn <role> [--id <id>]` | a teammate started working (`role`: `coder` `reviewer` `lead`) |
| `dex agent idle <role>` | a teammate went idle |

## Stories

| Command | Effect |
|---|---|
| `dex story add --id <id> --title "<name>" [--summary "<summary>"]` | register a build story (emits `story.+`) |
| `dex story start <id>` | mark a story in progress |
| `dex story done <id> [--commit <sha>]` | mark a story complete — the lead's call, after its review passes |
| `dex story ls` | list the spec's stories with status |
| `dex story next` | print the next un-built story (`<id> <title>`); empty + exit 1 when all are done |

## Observations

| Command | Effect |
|---|---|
| `dex test --passed <P> --failed <F> [--cmd "<cmd>"]` | record a test run |
| `dex review --round <N> --verdict <pass\|fail\|notes> [--blockers <b>] [--issues <i>]` | reviewer verdict |
| `dex gate --provider <ci\|review> [--name <check>] --result <result> [--score <0-5>]` | a PR gate landed (`result`: `success` `failure` `cancelled` `skipped` `timed_out` `neutral` `pending`) |
| `dex pr --number <N> --url <url> [--state open\|merged\|closed]` | record the PR (state defaults to `open`; flip to `merged`/`closed` when the host reports it) |
| `dex note --level <info\|warn\|error> --topic <topic> --text "<observation>"` | freeform signal (the curator/watcher feed) |

`ci` and `review` are **roles**, not vendors — config maps them to a tool.

## Notes & lessons

| Command | Effect |
|---|---|
| `dex notes [--scope spec\|project\|skill] [--topic <t>] [--level <l>]` | aggregate notes across all specs in the registry (global) |
| `dex lessons list\|show\|add` | manage per-project lessons (durable insights) |

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
