#!/usr/bin/env bash
# Update specdex: pull latest, build the macOS .app, install it to /Applications.
# This IS the updater — run it whenever you want the app on the latest commit.
# Usage: apps/desktop/install.sh        (pull + build + install)
#        apps/desktop/install.sh --dmg  (also produce a .dmg)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"   # …/apps/specdex/apps/desktop
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"        # …/apps/specdex (the cargo workspace root)
cd "$SCRIPT_DIR"
APP="$ROOT/target/release/bundle/macos/specdex.app"
DEST="/Applications/specdex.app"

BUNDLES="app"
[ "${1:-}" = "--dmg" ] && BUNDLES="app,dmg"

echo "→ pulling latest…"
git -C "$ROOT" pull --ff-only || echo "  (skip pull — local ahead/dirty, building current tree)"

echo "→ building specdex.app (release)…"
cargo tauri build --bundles "$BUNDLES"

[ -d "$APP" ] || { echo "build produced no .app at $APP" >&2; exit 1; }

echo "→ installing to $DEST"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

# unsigned local build — clear the quarantine bit so Gatekeeper opens it
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "✓ installed → $DEST   (open -a specdex)"
