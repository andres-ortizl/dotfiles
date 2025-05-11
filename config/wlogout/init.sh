#!/bin/bash

SHOT=/tmp/shot.png
BLURRED=/tmp/shot_blurred.png

grim -t png "$SHOT"
convert "$SHOT" -blur 0x4 "$BLURRED" &
wlogout --layout "$HOME/.config/wlogout/layout" \
        --css "$HOME/.config/wlogout/style.css" \
        -b 4 --protocol layer-shell
