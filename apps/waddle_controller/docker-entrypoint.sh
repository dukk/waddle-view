#!/bin/sh
# Supervise nginx (edge TLS + SPA) and the Node BFF. If either exits, stop the other
# and exit non-zero so Docker can restart the container.
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

NODE_PID=""
NGINX_PID=""

shutdown() {
  echo "Shutting down waddle-controller…" >&2
  if [ -n "$NGINX_PID" ]; then
    kill -TERM "$NGINX_PID" 2>/dev/null || true
  fi
  if [ -n "$NODE_PID" ]; then
    kill -TERM "$NODE_PID" 2>/dev/null || true
  fi
  if [ -n "$NGINX_PID" ]; then
    wait "$NGINX_PID" 2>/dev/null || true
  fi
  if [ -n "$NODE_PID" ]; then
    wait "$NODE_PID" 2>/dev/null || true
  fi
}

trap shutdown TERM INT

cd /app
node server/dist/index.js &
NODE_PID=$!

# Wait for BFF health or early crash (avoids nginx 502s during slow startup).
i=0
while [ "$i" -lt 30 ]; do
  if ! kill -0 "$NODE_PID" 2>/dev/null; then
    echo "BFF exited during startup" >&2
    wait "$NODE_PID" 2>/dev/null || true
    exit 1
  fi
  if wget -qO- "http://127.0.0.1:${PORT}/bff/health" >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 1
done
if [ "$i" -ge 30 ]; then
  echo "BFF did not become healthy within 30s" >&2
  shutdown
  exit 1
fi

nginx -g "daemon off;" &
NGINX_PID=$!

while kill -0 "$NODE_PID" 2>/dev/null && kill -0 "$NGINX_PID" 2>/dev/null; do
  sleep 1
done

if kill -0 "$NODE_PID" 2>/dev/null; then
  echo "nginx exited unexpectedly; stopping BFF" >&2
  shutdown
  exit 1
fi

echo "BFF exited; stopping nginx" >&2
shutdown
wait "$NODE_PID" 2>/dev/null || true
exit 1
