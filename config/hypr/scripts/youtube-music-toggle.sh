#!/usr/bin/env bash

# Check if YouTube Music window exists
ADDR=$(hyprctl clients -j | jq -r '.[] | select(.title | contains("YouTube Music")) | .address')

if [ -z "$ADDR" ]; then
    # Window doesn't exist, create it on special workspace
    zen-bin --new-window https://music.youtube.com &
    sleep 2
    # Force the window to float and resize, then move to special workspace
    ADDR=$(hyprctl clients -j | jq -r '.[] | select(.title | contains("YouTube Music")) | .address')
    if [ -n "$ADDR" ]; then
        hyprctl dispatch togglefloating address:$ADDR
        hyprctl dispatch resizewindowpixel exact 1498 803,address:$ADDR
        hyprctl dispatch movewindowpixel exact 498 225,address:$ADDR
        hyprctl dispatch movetoworkspacesilent "special:music,address:$ADDR"
    fi
fi

# Toggle the special workspace to show/hide with animation
hyprctl dispatch togglespecialworkspace music
