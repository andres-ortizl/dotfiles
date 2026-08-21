#!/usr/bin/env bash
set -euo pipefail

wallpaper_dir="$1"
cache_dir="$2"
max_jobs=4

mkdir -p "$cache_dir"

running=0
while IFS= read -r -d '' image; do
    name="$(basename "$image")"
    thumbnail="$cache_dir/$name"

    if [[ -f "$thumbnail" && "$thumbnail" -nt "$image" ]]; then
        continue
    fi

    magick "$image" -thumbnail 'x640' -strip -quality 88 "$thumbnail" &
    ((running += 1))

    if (( running >= max_jobs )); then
        wait -n
        ((running -= 1))
    fi
done < <(find -L "$wallpaper_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0)

wait
