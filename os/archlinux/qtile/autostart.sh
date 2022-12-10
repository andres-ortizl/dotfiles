#!/bin/sh

#Blurring
picom --config ~/.config/picom/picom.conf &

# systray volume
volctl &

bash $HOME/.screenlayout/screenlayout.sh