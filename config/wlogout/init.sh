#!/bin/bash

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
