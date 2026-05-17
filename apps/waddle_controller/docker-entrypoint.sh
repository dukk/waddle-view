#!/bin/sh
set -e
export PORT="${PORT:-5199}"
export WADDLE_CONTROLLER_BIND="${WADDLE_CONTROLLER_BIND:-127.0.0.1}"
export WADDLE_CONTROLLER_DATA_DIR="${WADDLE_CONTROLLER_DATA_DIR:-/var/lib/waddle-controller}"
# Edge TLS is terminated by nginx; loopback BFF stays plain HTTP.
export WADDLE_CONTROLLER_TLS="${WADDLE_CONTROLLER_TLS:-0}"
mkdir -p "$WADDLE_CONTROLLER_DATA_DIR"
TLS_DIR="${WADDLE_CONTROLLER_TLS_DIR:-/etc/waddle-controller/tls}"
mkdir -p "$TLS_DIR"
if [ ! -f "$TLS_DIR/cert.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TLS_DIR/key.pem" -out "$TLS_DIR/cert.pem" \
    -days 825 -subj "/CN=waddle-controller"
fi
cd /app
node server/dist/index.js &
exec nginx -g "daemon off;"
