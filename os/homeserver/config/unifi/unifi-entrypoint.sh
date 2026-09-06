#!/bin/bash
set -eu

MONGO_PASS=$(cat "$FILE__MONGO_PASS")
export MONGO_PASS
unset FILE__MONGO_PASS

system_properties=/config/data/system.properties
if [ -f "$system_properties" ] && grep -Fq '~MONGO_PASS~' "$system_properties"; then
  sed -i "s/~MONGO_PASS~/${MONGO_PASS}/g" "$system_properties"
fi

exec /init "$@"
