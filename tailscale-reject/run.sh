#!/usr/bin/env bash
set -euo pipefail

NGINX_CONF="/data/nginx.conf"
SOCAT_CONF="/data/socat_forwards.sh"

echo "[reject] Starting addon"

# Generate config from options
/usr/local/bin/generate-config.sh

HAS_NGINX=false
HAS_SOCAT=false

# Start socat TCP forwards if any
if [ -f "$SOCAT_CONF" ] && grep -q "socat" "$SOCAT_CONF"; then
    echo "[reject] Starting TCP forwards..."
    source "$SOCAT_CONF"
    HAS_SOCAT=true
fi

# Start nginx for HTTP proxying if config exists and has http block
if [ -f "$NGINX_CONF" ] && grep -q "^http {" "$NGINX_CONF"; then
    echo "[reject] Starting nginx..."
    nginx -c "$NGINX_CONF" -g "daemon off;" &
    NGINX_PID=$!
    HAS_NGINX=true
fi

if [ "$HAS_NGINX" = false ] && [ "$HAS_SOCAT" = false ]; then
    echo "[reject] No forwards configured — sleeping"
    exec sleep infinity
fi

# Trap for clean shutdown
cleanup() {
    echo "[reject] Shutting down..."
    [ "$HAS_NGINX" = true ] && kill "$NGINX_PID" 2>/dev/null || true
    # Kill all socat processes
    pkill socat 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# Wait
if [ "$HAS_NGINX" = true ]; then
    wait $NGINX_PID
else
    wait
fi
