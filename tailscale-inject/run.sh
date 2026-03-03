#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="/data/compose"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

echo "[tailscale-inject] Starting addon"

# Generate compose files from options
/usr/local/bin/generate-compose.sh

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "[tailscale-inject] No compose file generated (no devices configured?)"
    echo "[tailscale-inject] Sleeping indefinitely — configure devices and restart"
    exec sleep infinity
fi

cd "$COMPOSE_DIR"

# Build the custom image (tailscale + socat)
echo "[tailscale-inject] Building tailscale-socat image..."
docker compose build --pull

# Start all services
echo "[tailscale-inject] Starting containers..."
docker compose up -d --force-recreate --remove-orphans

# Trap SIGTERM for clean shutdown
cleanup() {
    echo "[tailscale-inject] Shutting down containers (preserving state volumes)..."
    cd "$COMPOSE_DIR"
    docker compose down || true
    echo "[tailscale-inject] Shutdown complete"
    exit 0
}
trap cleanup SIGTERM SIGINT

# Monitor loop
while true; do
    sleep 300
    echo "[tailscale-inject] Status check:"
    cd "$COMPOSE_DIR"
    docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || true
done
