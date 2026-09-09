# herdr Command Deck

Prefix is `Ctrl+Space`. Press it, release, then the key. `Prefix ?` shows every binding.

## Floating TUIs, one keystroke, `q` quits

| Keys | Tool | What |
|------|------|------|
| `Ctrl+G` | lazygit | diffs, staging, commits |
| `Ctrl+D` | lazydocker | containers, logs, stats |
| `Ctrl+Y` | yazi | file manager + previews |
| `Ctrl+F` | btop | cpu, mem, procs |
| `Ctrl+B` | witr | who's on that port & why |
| `Prefix /` | glow | this cheatsheet |

Popups open in the focused pane's cwd and do not change the layout.

## Panes & splits

| Keys | Action |
|------|--------|
| `Cmd+D` / `Opt+R` / `Prefix V` | split right |
| `Cmd+Shift+D` / `Opt+Shift+D` / `Prefix -` | split down |
| `Cmd+W` / `Opt+W` / `Prefix X` | close pane |
| `Cmd+Opt+Arrows` / `Opt+HJKL` / `Prefix HJKL` | focus pane; H/L cross tabs at edge |
| `Prefix Tab` | last pane |
| `Prefix Z` or `Prefix F` | zoom pane |
| `Prefix R` | resize mode (hjkl, esc to leave) |
| `Prefix E` | edit scrollback |

## Tabs

| Keys | Action |
|------|--------|
| `Cmd+T` / `Opt+T` / `Prefix C` | new tab |
| `Opt+Shift+W` / `Prefix Shift+X` | close tab |
| `Opt+1..9` | jump to tab |
| `Opt+I` / `Opt+O` | previous / next tab |
| `Prefix Shift+T` | rename tab |

## Workspaces, worktrees, agents

| Keys | Action |
|------|--------|
| `Prefix W` | workspace picker |
| `Prefix G` | goto (fuzzy jump) |
| `Prefix Shift+N` | new workspace |
| `Prefix Shift+G` | new git worktree (lands in ~/code/worktrees) |
| `Prefix Shift+E` | open active workspace in Zed |
| `Prefix I` | Linear issue → worktree + workspace |
| `Prefix D` | review diff / PR sidebar (reviewr) |
| `Prefix Space` | pane navigator (fuzzy, sorted by agent urgency) |
| `Cmd+K` / `Prefix Shift+K` | command bar: jump anywhere |
| `Prefix T` | theme picker |
| `Opt+Shift+J/K` | next / previous workspace |
| `Opt+Shift+H/L` | previous / next agent |
| `Prefix Opt+1..9` | focus agent N |
| `Cmd+1` / `Prefix B` | toggle sidebar |
| `Prefix O` | open notification target |

## Session

| Keys | Action |
|------|--------|
| `Prefix Q` | detach (server keeps running) |
| `Prefix S` | settings menu |
| `Prefix Shift+R` | reload config |
| `herdr` | reattach from any terminal |
| `herdr --remote host` | attach to a remote server |

## Handy CLI

```
herdr agent list                 # who is working / blocked / idle
herdr worktree create <branch>   # new worktree workspace
herdr plugin list                # installed plugins
herdr plugin action list         # action ids for keybindings
```
