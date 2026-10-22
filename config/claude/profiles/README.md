# Claude agent profiles

Personal rules per repository, added on top of the generic stack. They are Andrew's, not the team's: nothing here is committed to the repository it applies to.

## Layers

| Layer | File | Loaded for |
|---|---|---|
| Generic rules | `dotfiles/AGENTS.md` (= `~/.claude/CLAUDE.md`) | every session and subagent, every repo |
| Generic agents | `config/claude/agents/{explorer,coder,reviewer}.md` | the agent of that name, every repo |
| Repo rules (team) | the repo's own `CLAUDE.md`, `CONTRIBUTING.md`, `.greptile/` | everyone working in that repo |
| Repo profile (personal) | `config/claude/profiles/<repo>/<role>.md` | Andrew's sessions in that repo only |
| Facts | auto-memory (`~/.claude/projects/.../memory/`) | the main agent only; subagents never see it |

A rule goes in the narrowest layer that holds it: a rule for every repo goes in `AGENTS.md`, a rule for one repo goes in its profile, and a fact that is not an instruction stays in memory.

## Roles

| Role | Agent | Model | Profile file |
|---|---|---|---|
| main | the session you talk to | your session model | `main.md` |
| explorer | `explorer` | Haiku | `explorer.md` |
| coder | `coder`, `claude-pm:project-developer` | Sonnet | `coder.md` |
| reviewer | `reviewer`, `claude-pm:code-review-reporter` | Opus | `reviewer.md` |

Any other agent type gets no profile. The built-in `Explore` agent is denied (`permissions.deny: ["Agent(Explore)"]`) because it skips `CLAUDE.md`.

## How a profile is loaded

`config/claude/hooks/profile.sh` runs on two hooks in `~/.claude/settings.json`:

- `SessionStart` adds `main.md` to the main agent.
- `SubagentStart` adds the role's file to each subagent. `SessionStart` context never reaches subagents, so they need their own hook.

The hook finds the profile from the session's directory: `git remote -v` must contain `anyformat-ai/anyformat-monorepo` for the `anyformat` profile. This matches every worktree of the repo. Anything else (another repo, no git, a missing file, bad input) prints `{}` and adds nothing.

## Add a profile for another repo

1. Create `profiles/<name>/` with the role files you need. A missing file means no extra rules for that role.
2. Add a branch to the `case "$remotes"` block in `profile.sh` that matches the repo's remote and sets `profile=<name>`.
3. Check it: `echo '{"hook_event_name":"SubagentStart","cwd":"<repo path>","agent_type":"coder"}' | config/claude/hooks/profile.sh`

## Change a rule

Edit the file; it applies from the next session or subagent. Rules come from the retro of a loop (`slices retro`): a signal that repeats becomes a line in the narrowest layer that holds it.
