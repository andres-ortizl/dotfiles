#!/bin/sh
set -e

# Patch the web frontend with the correct API URL at runtime
if [ -n "$API_URL" ]; then
    echo "Patching web frontend with API_URL: $API_URL"
    sed -i "s|http://localhost:9000|$API_URL|g" /app/web/build/_app/env.js
    sed -i "s|http://localhost:9000|$API_URL|g" /app/web/build/_app/immutable/chunks/*.js 2>/dev/null || true
fi

# Start both the API and web server
exec python3 -m http.server 9001 --directory /app/web/build & node /app/src/cobalt
