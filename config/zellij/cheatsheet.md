# Zellij Command Deck

## Floating TUIs — one keystroke, `q` quits

| Keys | Tool | What |
|------|------|------|
| `Ctrl+G` | lazygit | diffs, staging, commits |
| `Ctrl+D` | lazydocker | containers, logs, stats |
| `Ctrl+Y` | yazi | file manager + previews |
| `Ctrl+F` | btop | cpu, mem, procs |
| `Ctrl+B` | witr | who's on that port & why |
| `Ctrl+P` then `?` | glow | this cheatsheet |

Floats open in the focused pane's cwd. Hide/show all floats without
quitting: `Ctrl+P` then `W`.

## Panes & splits

| Keys | Action |
|------|--------|
| `Cmd+D` | split right |
| `Cmd+Shift+D` | split down |
| `Opt+N` | new pane (auto placement) |
| `Cmd+W` | close pane |
| `Cmd+Opt+Arrows` / `Opt+HJKL` | focus pane (h/l cross into tabs) |
| `Opt+[` `Opt+]` | cycle swap layouts |
| `Opt+ +/-` | resize focused pane |

Every `Cmd` combo is a Ghostty alias typing the same ESC sequence as
its `Opt` twin.

## Tabs

| Keys | Action |
|------|--------|
| `Cmd+T` | new tab |
| `Cmd+Shift+W` | close tab |
| `Opt+H` / `Opt+L` | previous / next tab (at tab edge) |
| `Opt+I` / `Opt+O` | drag tab left / right |
| `Ctrl+T` then `1..9` | jump to tab N |
| `Ctrl+T` then `B` | break pane into new tab |
| `Ctrl+T` then `R` | rename tab |

## Modes — chord, then key

| Chord | Mode | Inside |
|-------|------|--------|
| `Ctrl+P` | pane | n/d/r new · x close · f fullscreen · w toggle floats · e embed<->float · i pin · c rename |
| `Ctrl+T` | tab | n new · x close · r rename · s sync |
| `Ctrl+N` | resize | hjkl grow · HJKL shrink |
| `Ctrl+H` | move | hjkl relocate pane |
| `Ctrl+S` | scroll | j/k line · d/u half · e edit in nvim · s search |
| `Ctrl+O` | session | d detach · w manager · s share · c config |
| `Ctrl+Q` | quit zellij | |

`Esc` or `Enter` returns to normal mode.

## Scrollback

| Keys | Action |
|------|--------|
| `PgUp` / `PgDn` | scroll pane directly |
| `Cmd+Shift+Up/Down` | ghostty buffer top / bottom |

## Shell line editing — intact

| Keys | Action |
|------|--------|
| `Opt+Left/Right` | jump word |
| `Opt+Backspace` / `Opt+Delete` | delete word back / forward |
| `Ctrl+R` | history search |
| `Shift+Enter` | literal newline |

## Keys traded away

- `Ctrl+D` EOF is gone — type `exit` to close shells & REPLs
- `Ctrl+G` lock mode — no longer reachable
- `Ctrl+B` tmux mode — retired for witr
- `Ctrl+F` / `Ctrl+Y` zsh editing — rarely used, gone

## After editing configs

- `Cmd+Shift+,` reloads Ghostty config
- New zellij session (or new tab for the bar) picks up the keymap
- Running instances keep their birth keymap — disk is not live
