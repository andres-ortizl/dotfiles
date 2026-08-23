#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.local/bin/soloist-tui"

cd "$ROOT"
echo "→ building soloist-tui (release)…"
cargo build --release --locked
install -Dm755 target/release/soloist-tui "$DEST"
echo "✓ installed → $DEST"
