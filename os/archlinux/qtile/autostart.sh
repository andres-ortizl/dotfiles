#!/bin/sh

#Blurring
picom --experimental-backends --config ~/.config/picom/picom.conf &

# systray volume
volctl &

$HOME/.screenlayout/screenlayout.sh