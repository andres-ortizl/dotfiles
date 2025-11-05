#!/bin/bash

timeout=3
lockdir="$HOME/.config/waybar/store/getnotification.lock"

# if getnotification.sh is not running, start it
# Use both pgrep and lockdir check for reliability
if ! pgrep -f "getnotification.sh$" > /dev/null && [ ! -d "$lockdir" ]; then
    $HOME/.config/waybar/scripts/getnotification.sh &
    # Give it time to start and acquire the lock
    sleep 0.5
fi


while true; do
    dunststatus=$(dunstctl is-paused)
    realtime=$(date +%s)

    while IFS=': ' read -r key value; do
        case $key in
            timestamp) timestamp=$value ;;
            appname) appname=$value ;;
            summary) summary=$value ;;
            body) body=$value ;;
            icon) icon=$value ;;
        esac
    done < ~/.config/waybar/store/lastnotif

    # Calculate the difference between the current time and the timestamp
    timediff=$(($realtime - $timestamp))

    if [ $timediff -gt $(($timeout - 1)) ]; then
        if [ $dunststatus = "false" ]; then
            echo '{"text": "󰂚", "alt": "notification", "class": "collapsed"}' | jq --unbuffered --compact-output
        else
            echo '{"text": "󰂚", "alt": "notification", "class": "collapsed_muted"}' | jq --unbuffered --compact-output
        fi
        sleep 0.3
    else
        if [ $dunststatus = "false" ]; then
            if [ "$summary" = "swww" ] && [ "$body" = 1 ]; then
                timeout=2
                echo '{"text": "", "alt": "notification", "class": "wallpaper"}' | jq --unbuffered --compact-output
                sleep 0.3
            else
                timeout=3
                echo '{"text": "󰂚", "alt": "notification", "class": "waiting_start"}' | jq --unbuffered --compact-output
                sleep 0.3
                echo '{"text": "'$summary': '$body'", "alt": "notification", "class": "expanded"}' | jq --unbuffered --compact-output
                sleep $timeout
                echo '{"text": "󰂚", "alt": "notification", "class": "waiting_done"}' | jq --unbuffered --compact-output
                sleep 0.4
            fi
        fi
    fi
done
