#!/usr/bin/env bash

dispatch_compat() {
  local lua_dispatcher="$1"
  local legacy_dispatcher="$2"
  shift 2

  hyprctl dispatch "$lua_dispatcher" >/dev/null 2>&1 ||
    hyprctl dispatch "$legacy_dispatcher" "$@"
}

# Check if YouTube Music window exists
ADDR=$(hyprctl clients -j | jq -r '.[] | select(.title | contains("YouTube Music")) | .address')

if [ -z "$ADDR" ]; then
  # Window doesn't exist, create it on special workspace
  "$HOME/.config/hypr/scripts/launch-app" zen-bin --new-window https://music.youtube.com &
  sleep 2
  # Force the window to float and resize, then move to special workspace
  ADDR=$(hyprctl clients -j | jq -r '.[] | select(.title | contains("YouTube Music")) | .address')
  if [ -n "$ADDR" ]; then
    dispatch_compat "hl.dsp.window.float({ action = 'toggle', window = 'address:$ADDR' })" togglefloating "address:$ADDR"
    dispatch_compat "hl.dsp.window.resize({ x = 1498, y = 803, window = 'address:$ADDR' })" resizewindowpixel exact 1498 "803,address:$ADDR"
    dispatch_compat "hl.dsp.window.move({ x = 498, y = 225, window = 'address:$ADDR' })" movewindowpixel exact 498 "225,address:$ADDR"
    dispatch_compat "hl.dsp.window.move({ workspace = 'special:music', follow = false, window = 'address:$ADDR' })" movetoworkspacesilent "special:music,address:$ADDR"
  fi
fi

# Toggle the special workspace to show/hide with animation
dispatch_compat 'hl.dsp.workspace.toggle_special("music")' togglespecialworkspace music
