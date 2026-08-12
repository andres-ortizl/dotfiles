#!/bin/sh

if hyprctl clients -j | jq -e '.[] | select(.class == "scratchpad.lazyt")' >/dev/null; then
    hyprctl dispatch togglespecialworkspace lazyt
    exit 0
fi

ghostty --class=scratchpad.lazyt -e /home/andres/.local/bin/lazyt &
sleep 0.4
hyprctl dispatch togglespecialworkspace lazyt
