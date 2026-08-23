#!/bin/sh

music_is_visible() {
    hyprctl monitors -j | jq -e '.[] | select(.specialWorkspace.name == "special:music")' >/dev/null
}

toggle_music() {
    was_visible=0
    music_is_visible && was_visible=1
    toggle_attempt=0

    while [ "$toggle_attempt" -lt 3 ]; do
        hyprctl dispatch togglespecialworkspace music >/dev/null
        sleep 0.2
        if [ "$was_visible" -eq 1 ] && ! music_is_visible; then
            return 0
        fi
        if [ "$was_visible" -eq 0 ] && music_is_visible; then
            return 0
        fi
        toggle_attempt=$((toggle_attempt + 1))
    done

    return 1
}

soloist_exists() {
    hyprctl clients -j | jq -e '.[] | select(.class == "scratchpad.soloist")' >/dev/null
}

if soloist_exists; then
    toggle_music
    exit 0
fi

runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
lock_file="$runtime_dir/soloist-tui-scratchpad-$(id -u).lock"
exec 9>"$lock_file"
flock -n 9 || exit 0

if soloist_exists; then
    exit 0
fi

"$HOME/.config/hypr/scripts/launch-app" ghostty --class=scratchpad.soloist -e "$HOME/.local/bin/soloist-tui" 9>&- &

attempt=0
while [ "$attempt" -lt 50 ]; do
    if soloist_exists; then
        toggle_music
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done

exit 1
