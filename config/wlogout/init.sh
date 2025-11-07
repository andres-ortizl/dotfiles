#!/bin/bash

SHOT=/tmp/shot.png
BLURRED=/tmp/shot_blurred.png


grim -t png "$SHOT"
magick "$SHOT" -blur 0x8 "$BLURRED" &

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
