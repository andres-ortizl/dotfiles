#!/usr/bin/env bash
set -euo pipefail

wallpaper="$1"
wallpaper_dir="$(dirname "$wallpaper")"
selected_name="$(basename "$wallpaper")"

mapfile -t wallpapers < <(find -L "$wallpaper_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -printf '%f\n' | sort)
for index in "${!wallpapers[@]}"; do
    if [[ "${wallpapers[$index]}" == "$selected_name" ]]; then
        printf '%s\n' "$((index + 1))" > "$HOME/.config/hypr/store/wallpaper"
        break
    fi
done

if ! pgrep -x awww-daemon >/dev/null; then
    awww-daemon &
    for _ in {1..20}; do
        pgrep -x awww-daemon >/dev/null && break
        sleep 0.1
    done
fi

awww img "$wallpaper" -t random --transition-duration 1
"$HOME/.config/hypr/scripts/apply-wallpaper-theme" "$wallpaper"
