#!/bin/bash

GREEN='\e[1;32m'
NC='\033[0m' # No Color
GREY='\e[0;90m'

mkdir -p ~/.config/waybar/store

notif_file=~/.config/waybar/store/lastnotif
lockdir=~/.config/waybar/store/getnotification.lock

# Use mkdir for atomic locking (mkdir is atomic on most filesystems)
if ! mkdir "$lockdir" 2>/dev/null; then
    # Lock directory already exists, another instance is running
    echo "getnotification.sh is already running. Exiting." >&2
    exit 0
fi

# Clean up lock directory on exit
trap "rmdir '$lockdir' 2>/dev/null" EXIT INT TERM

echo "timestamp: 1
icon:
appname: waybar
summary: Hello!
body: " > "$notif_file"

dbus-monitor "interface='org.freedesktop.Notifications'" | grep --line-buffered "member=Notify\|string" | while read line; do
    printf "${GREY}debug: $line${NC}\n" >&2
    if [[ $line == *"member=Notify"* ]]; then
        timestamp=$(echo $line | sed 's/.*time=\([0-9]*\).*/\1/')
        printf "\n${GREEN}timestamp:${NC} $timestamp\n" >&2
        linenumber=0
        appname=""
        icon=""
        summary=""
        body=""
    else
        if [[ $line == *"string"* ]]; then
            linenumber=$((linenumber + 1))

            if [ $linenumber -eq 1 ]; then
                appname=$(echo "$line" | sed 's/string //g; s/\"//g')
                printf "${GREEN}appname:${NC} $appname\n" >&2
            fi

            if [ $linenumber -eq 2 ]; then
                icon=$(echo $line | sed 's/string //g; s/\"//g')
                printf "${GREEN}icon:${NC} $icon\n" >&2
            fi

            if [ $linenumber -eq 3 ]; then
                summary=$(echo $line | sed 's/string //g; s/\"//g')
                printf "${GREEN}summary:${NC} $summary\n" >&2
            fi

            if [ $linenumber -eq 4 ]; then
                body=$(echo $line | sed 's/string //g; s/\"//g')
                printf "${GREEN}body:${NC} $body\n" >&2

                cat > "$notif_file" <<EOF
timestamp: $timestamp
appname: $appname
icon: $icon
summary: $summary
body: $body
EOF
            fi
        fi
    fi
done
