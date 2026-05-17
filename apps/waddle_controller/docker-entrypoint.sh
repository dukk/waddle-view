#!/bin/sh
set -e
export PORT="${PORT:-5199}"
export WADDLE_CONTROLLER_BIND="${WADDLE_CONTROLLER_BIND:-127.0.0.1}"
export WADDLE_CONTROLLER_DATA_DIR="${WADDLE_CONTROLLER_DATA_DIR:-/var/lib/waddle-controller}"
mkdir -p "$WADDLE_CONTROLLER_DATA_DIR"
cd /app
node server/dist/index.js &
exec nginx -g "daemon off;"
