#!/bin/bash

# Generate blurred background if missing
if [ ! -f /tmp/shot_blurred.png ]; then
    grim -o "$(hyprctl monitors -j | jq -r '.[0].name')" /tmp/shot.png
    magick /tmp/shot.png -blur 0x8 /tmp/shot_blurred.png
    rm /tmp/shot.png
fi

wlogout --layout "$HOME/.config/wlogout/layout" \
  --css "$HOME/.config/wlogout/style.css" \
  --buttons-per-row 3 \
  --column-spacing 50 \
  --row-spacing 50 \
  --margin-top 300 \
  --margin-bottom 300 \
  --margin-left 400 \
  --margin-right 400 \
  --protocol layer-shell
