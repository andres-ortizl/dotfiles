#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
spotify_path="${XDG_DATA_HOME:-$HOME/.local/share}/spotify-launcher/install/usr/share/spotify"
prefs_path="${XDG_CONFIG_HOME:-$HOME/.config}/spotify/prefs"

music_is_visible() {
    hyprctl monitors -j | jq -e '.[] | select(.specialWorkspace.name == "special:music")' >/dev/null
}

spotify_exists() {
    hyprctl clients -j | jq -e '.[] | select(((.class // "") | ascii_downcase) == "spotify")' >/dev/null
}

spotify_running() {
    pgrep -x spotify >/dev/null
}

toggle_music() {
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("music")' >/dev/null 2>&1 ||
        hyprctl dispatch togglespecialworkspace music >/dev/null
}

show_music() {
    music_is_visible || toggle_music
}

notify_error() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "Spotify" "$1"
    fi
    printf '%s\n' "$1" >&2
}

if spotify_exists; then
    toggle_music
    exit 0
fi

for command_name in spotify-launcher spicetify; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        notify_error "Missing command: $command_name"
        exit 1
    fi
done

runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
lock_file="$runtime_dir/spotify-scratchpad-$(id -u).lock"
exec 9>"$lock_file"
flock -n 9 || exit 0

if spotify_exists; then
    show_music
    exit 0
fi

if ! spotify_running; then
    if ! spotify-launcher --no-exec; then
        if [[ ! -x "$spotify_path/spotify" ]]; then
            notify_error "Spotify could not be downloaded or updated."
            exit 1
        fi
    fi

    if [[ -f "$prefs_path" ]]; then
        if ! "$script_dir/apply-spicetify"; then
            notify_error "Spicetify failed. Starting the unmodified Spotify client."
        fi
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send "Spotify" "Close and reopen Spotify once to apply Spicetify."
    fi
fi

"$script_dir/launch-app" spotify-launcher --skip-update 9>&- &

attempt=0
while [[ $attempt -lt 100 ]]; do
    if spotify_exists; then
        show_music
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done

notify_error "Spotify started but Hyprland did not find its window."
exit 1
