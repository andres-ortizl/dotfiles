#!/bin/bash

# Get the GPU temperature from nvidia-smi
GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)

# Determine the icon based on GPU temperature
case $GPU_TEMP in
    [0-3][0-9]) ICON="󰝦" ;;   # 0-39°C
    [4-5][0-9]) ICON="󰪞" ;;   # 40-59°C
    [6-7][0-9]) ICON="󰪟" ;;   # 60-79°C
    8[0-9]) ICON="󰪣" ;;       # 80-89°C
    9[0-9]) ICON="󰪤" ;;       # 90-99°C
    1[0-9][0-9]) ICON="󰪥" ;;  # 100-199°C (unlikely, but for safety)
    *) ICON="󰪠" ;;             # Default (any unexpected value)
esac

# Output JSON format for Waybar
echo "{\"text\": \"$ICON $GPU_TEMP°C\", \"tooltip\": \"$GPU_TEMP°C\", \"icon\": \"$ICON\"}"
