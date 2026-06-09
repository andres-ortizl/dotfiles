#!/usr/bin/env bash
# specdex app entrypoint — delegates to the Tauri desktop build/install.
# Convention: every apps/<name>/install.sh installs that app; `./install --apps` runs them all.
exec "$(cd "$(dirname "$0")" && pwd)/apps/desktop/install.sh" "$@"
