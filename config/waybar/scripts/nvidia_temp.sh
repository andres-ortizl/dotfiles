#!/bin/bash

GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)

case $GPU_TEMP in
    [0-3][0-9]) ICON="󰝦" ;;   # 0-39°C
    [4-5][0-9]) ICON="󰪞" ;;   # 40-59°C
    [6-6][0-9]) ICON="󰪟" ;;   # 60-69°C
    [7-7][0-9]) ICON="󰪣" ;;   # 70-79°C
    [8-8][0-9]) ICON="󰪤" ;;   # 80-89°C
    [9-9][0-9]) ICON="󰪥" ;;   # 90-99°C
    *) ICON="󰪦" ;;             # Default (any unexpected value)
esac

echo "{\"text\": \"$ICON $GPU_TEMP°C\", \"tooltip\": \"GPU Temperature: $GPU_TEMP°C\"}"
