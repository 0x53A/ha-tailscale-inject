#!/usr/bin/env bash
set -euo pipefail

OPTIONS="/data/options.json"
NGINX_CONF="/data/nginx.conf"
SOCAT_CONF="/data/socat_forwards.sh"

FORWARD_COUNT=$(jq '.forwards | length' "$OPTIONS")

if [ "$FORWARD_COUNT" -eq 0 ]; then
    echo "[generate-config] No forwards configured"
    rm -f "$NGINX_CONF" "$SOCAT_CONF"
    exit 0
fi

# Start nginx config
cat > "$NGINX_CONF" <<'HEADER'
worker_processes 1;
pid /tmp/nginx.pid;
error_log /dev/stderr warn;

events {
    worker_connections 256;
}

HEADER

HAS_HTTP=false

# Start socat script
cat > "$SOCAT_CONF" <<'HEADER'
#!/usr/bin/env bash
# Auto-generated socat forwards
HEADER
chmod +x "$SOCAT_CONF"

for i in $(seq 0 $((FORWARD_COUNT - 1))); do
    NAME=$(jq -r ".forwards[$i].name" "$OPTIONS")
    LISTEN_PORT=$(jq -r ".forwards[$i].listen_port" "$OPTIONS")
    TARGET=$(jq -r ".forwards[$i].target" "$OPTIONS")
    MODE=$(jq -r ".forwards[$i].mode" "$OPTIONS")

    if [ "$MODE" = "tcp" ]; then
        # Parse target as ip:port
        TARGET_HOST="${TARGET%%:*}"
        TARGET_PORT="${TARGET##*:}"
        echo "[generate-config] TCP forward '$NAME': :${LISTEN_PORT} -> ${TARGET_HOST}:${TARGET_PORT}"
        cat >> "$SOCAT_CONF" <<EOF
echo "[reject] Starting TCP forward: :${LISTEN_PORT} -> ${TARGET_HOST}:${TARGET_PORT} (${NAME})"
socat TCP4-LISTEN:${LISTEN_PORT},fork,reuseaddr TCP4:${TARGET_HOST}:${TARGET_PORT} &
EOF

    elif [ "$MODE" = "http" ]; then
        # Target is a URL (possibly https)
        echo "[generate-config] HTTP proxy '$NAME': :${LISTEN_PORT} -> ${TARGET}"
        HAS_HTTP=true

        # nginx needs the stream or http block depending on use
        if [ "$i" -eq 0 ] || ! grep -q "^http {" "$NGINX_CONF" 2>/dev/null; then
            # Only write http block header once
            if ! grep -q "^http {" "$NGINX_CONF" 2>/dev/null; then
                cat >> "$NGINX_CONF" <<'HTTP_HEADER'
http {
    access_log /dev/stdout;

    # Temp paths for non-root
    client_body_temp_path /tmp/nginx_client_body;
    proxy_temp_path /tmp/nginx_proxy;
    fastcgi_temp_path /tmp/nginx_fastcgi;
    uwsgi_temp_path /tmp/nginx_uwsgi;
    scgi_temp_path /tmp/nginx_scgi;

HTTP_HEADER
            fi
        fi

        cat >> "$NGINX_CONF" <<EOF
    server {
        listen ${LISTEN_PORT};
        server_name _;

        location / {
            proxy_pass ${TARGET};
            proxy_set_header Host \$proxy_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_buffering off;
        }
    }

EOF
    fi
done

# Close nginx http block if we have http forwards
if [ "$HAS_HTTP" = true ]; then
    echo "}" >> "$NGINX_CONF"
fi

echo "[generate-config] Wrote config with $FORWARD_COUNT forward(s)"
