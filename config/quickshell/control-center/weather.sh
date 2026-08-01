#!/usr/bin/env bash

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-control-center"
cache_file="$cache_dir/madrid-weather.json"
temp_file="$cache_file.tmp"
url="https://api.open-meteo.com/v1/forecast?latitude=40.4168&longitude=-3.7038&current=temperature_2m,apparent_temperature,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Europe%2FMadrid&forecast_days=1"

mkdir -p "$cache_dir"

if curl --fail --silent --show-error --max-time 8 "$url" --output "$temp_file"; then
  mv "$temp_file" "$cache_file"
else
  rm -f "$temp_file"
fi

if [[ -s "$cache_file" ]]; then
  cat "$cache_file"
else
  printf '{}\n'
fi
