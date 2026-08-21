#!/usr/bin/env bash
set -euo pipefail

wlogout \
    --layout "$HOME/.config/wlogout/layout" \
    --css "$HOME/.config/wlogout/style.css" \
    --buttons-per-row 6 \
    --column-spacing 16 \
    --row-spacing 0 \
    --margin-left 680 \
    --margin-right 680 \
    --margin-top 625 \
    --margin-bottom 625 \
    --protocol layer-shell
