#!/bin/sh

toggle_lazyt() {
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("lazyt")' >/dev/null 2>&1 ||
        hyprctl dispatch togglespecialworkspace lazyt
}

if hyprctl clients -j | jq -e '.[] | select(.class == "scratchpad.lazyt")' >/dev/null; then
    toggle_lazyt
    exit 0
fi

"$HOME/.config/hypr/scripts/launch-app" ghostty --class=scratchpad.lazyt -e "$HOME/.local/bin/lazyt" &
sleep 0.4
toggle_lazyt
