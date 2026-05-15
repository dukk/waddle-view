#!/bin/sh
set -e
export PORT="${PORT:-3000}"
cd /app
node dist/index.js &
exec nginx -g "daemon off;"
