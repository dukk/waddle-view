#!/bin/sh
set -e
export PORT="${PORT:-3000}"
export WADDLE_DISPLAY_HTTP_BIND_IP="${WADDLE_DISPLAY_HTTP_BIND_IP:-0.0.0.0}"
export WADDLE_DISPLAY_HTTP_TLS="${WADDLE_DISPLAY_HTTP_TLS:-0}"
export WADDLE_MOCK_DATA_DIR="${WADDLE_MOCK_DATA_DIR:-/var/lib/waddle-mock}"
TLS_DIR="${WADDLE_DISPLAY_HTTP_TLS_DIR:-/etc/waddle-mock/tls}"
mkdir -p "$TLS_DIR"
if [ ! -f "$TLS_DIR/cert.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TLS_DIR/key.pem" -out "$TLS_DIR/cert.pem" \
    -days 825 -subj "/CN=waddle-display-mock"
fi
cd /app
node dist/index.js &
exec nginx -g "daemon off;"
