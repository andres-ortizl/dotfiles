# soloist-tui

A fast Rust terminal client for Spotify Soloist. Soloist handles Spotify Connect and audio playback. This application adds a terminal interface for playback, queue control, search, library access, and playlists.

## Architecture

```text
Terminal UI ─┬─ local WebSocket ─ Spotify Soloist ─ PipeWire/PulseAudio
            └─ OAuth PKCE/HTTPS ─ Spotify Web API
```

The UI redraws on events. It only refreshes four times per second while playback is active.

## Requirements

- Linux with Spotify Soloist installed and paired
- Soloist started with its local WebSocket API enabled
- Optional: a Spotify Developer app for search, library access, and playlists
- Rust for local builds

Soloist must remain an external service. A typical command is:

```bash
soloist \
  --device-name "Living room" \
  --api-key "$SOLOIST_API_KEY" \
  --ws 127.0.0.1:0
```

Keep the WebSocket bound to `127.0.0.1`. Soloist does not provide authentication or TLS on this interface.

## Configure

The player opens in Soloist-only mode without Web API configuration. Playback controls and the live queue remain available.

To enable Search, Library, and Playlists, create a Spotify Developer app and register this redirect URI exactly:

```text
http://127.0.0.1:8888/callback
```

Then create the local configuration:

```bash
mkdir -p ~/.config/soloist-tui
cp config.example.toml ~/.config/soloist-tui/config.toml
$EDITOR ~/.config/soloist-tui/config.toml
```

Authenticate once:

```bash
cargo run -- auth
```

The refresh token is stored at `~/.local/share/soloist-tui/token.json` with mode `0600`.

## Run

```bash
cargo run --release
```

Install the binary into `~/.local/bin`:

```bash
./install.sh
```

## Keys

| Key | Action |
|---|---|
| `1` to `5` | Select Now Playing, Queue, Search, Library, or Playlists |
| `/` | Enter search mode |
| `Enter` | Submit search or play the selected item |
| `Esc` | Leave search mode |
| `j` / `k`, arrows | Move selection |
| `Space` | Play or pause |
| `n` / `p` | Next or previous item |
| Left / Right | Seek 10 seconds |
| `+` / `-` | Change volume |
| `s` | Toggle shuffle |
| `r` | Cycle repeat mode |
| `a` | Add the selected track to the queue |
| `l` / `d` | Save or remove the selected item from the library |
| `[` / `]` | Change library item type |
| `g` | Refresh the active view |
| `q` | Quit |

## Validation

```bash
cargo test
cargo clippy --all-targets --all-features -- -D warnings
cargo fmt --all -- --check
```
