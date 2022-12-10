#!/bin/sh

#Blurring
picom --config ~/.config/picom/picom.conf &

# systray volume
volctl &

#nitrogen
nitrogen --restore &

