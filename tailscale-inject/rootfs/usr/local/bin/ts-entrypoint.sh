#!/bin/sh
set -e

# Environment variables (set by docker-compose):
#   TS_HOSTNAME     — Tailscale hostname
#   TS_AUTH_KEY     — Tailscale auth key
#   TS_USERSPACE    — "true"
#   FORWARD_TARGET  — LAN IP to forward to
#   FORWARD_PORTS   — "631/tcp,9100/tcp,5353/udp"

echo "[ts-entrypoint] Starting for ${TS_HOSTNAME} -> ${FORWARD_TARGET}"

# Start tailscaled in userspace mode
tailscaled --tun=userspace-networking --statedir=/var/lib/tailscale &
TAILSCALED_PID=$!

# Wait for tailscaled socket
i=0
while [ $i -lt 30 ]; do
    if tailscale status >/dev/null 2>&1; then
        break
    fi
    sleep 1
    i=$((i + 1))
done

# Authenticate if not already connected
if ! tailscale status 2>/dev/null | grep -q "^100\."; then
    echo "[ts-entrypoint] Authenticating as ${TS_HOSTNAME}..."
    tailscale up --hostname="${TS_HOSTNAME}" --authkey="${TS_AUTH_KEY}" --accept-routes=false
else
    echo "[ts-entrypoint] Already authenticated"
fi

echo "[ts-entrypoint] Tailscale is up"
tailscale status

# Parse and start socat forwarders
OLD_IFS="$IFS"
IFS=','
for SPEC in $FORWARD_PORTS; do
    PORT="${SPEC%%/*}"
    PROTO="${SPEC##*/}"

    if [ "$PROTO" = "udp" ]; then
        echo "[ts-entrypoint] socat: UDP :${PORT} -> ${FORWARD_TARGET}:${PORT}"
        socat UDP4-LISTEN:${PORT},fork,reuseaddr UDP4:${FORWARD_TARGET}:${PORT} &
    else
        echo "[ts-entrypoint] socat: TCP :${PORT} -> ${FORWARD_TARGET}:${PORT}"
        socat TCP4-LISTEN:${PORT},fork,reuseaddr TCP4:${FORWARD_TARGET}:${PORT} &
    fi
done
IFS="$OLD_IFS"

echo "[ts-entrypoint] All forwarders started, waiting on tailscaled (PID ${TAILSCALED_PID})"
wait $TAILSCALED_PID
