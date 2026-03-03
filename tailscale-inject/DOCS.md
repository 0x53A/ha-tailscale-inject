# Tailscale Inject

Bridge LAN devices into your Tailscale network (and vice versa) with per-device node identities.

## What It Does

Each configured device gets its own Tailscale container with a unique node identity. This means:

- **Per-device ACLs** — control access to each device independently in Tailscale admin
- **Node sharing** — share individual devices with friends via Tailscale's sharing feature
- **Clean separation** — each device appears as its own node in your tailnet

## Modes

### Inject Mode (LAN → Tailnet)

Expose a LAN device (e.g., a printer) as a Tailscale node. Tailnet users can access the device's ports as if they were directly connected.

### Reverse Mode (Tailnet → LAN)

Expose a Tailscale service on your local LAN. Useful for devices that can't run Tailscale (e.g., Roku, smart TVs) to access tailnet services.

## Configuration

### Auth Key

Generate a reusable auth key in the [Tailscale admin console](https://login.tailscale.com/admin/settings/keys). Set it as the global `auth_key`, or per-device if you need different keys.

### Devices

Each device needs:
- **name**: Becomes the Tailscale hostname and must be unique
- **mode**: `inject` (LAN → tailnet) or `reverse` (tailnet → LAN)
- **ip**: The target IP address (LAN IP for inject, tailnet IP for reverse)
- **ports**: List of ports to forward (e.g., `631`, `9100/tcp`, `5353/udp`)
- **auth_key** (optional): Override the global auth key for this device

### Example

```yaml
auth_key: "tskey-auth-abc123..."
devices:
  - name: "home-printer"
    mode: "inject"
    ip: "192.168.178.50"
    ports:
      - "631"
      - "9100/tcp"

  - name: "jellyfin"
    mode: "reverse"
    ip: "100.64.1.5"
    ports:
      - "8096"
```

## How It Works

The addon spawns one Docker container per device using Docker Compose. Each container:
1. Runs Tailscale in userspace mode (no kernel module needed)
2. Authenticates with the provided auth key
3. Uses socat to forward ports between the tailnet and LAN

Tailscale state is stored in named Docker volumes, so authentication persists across restarts.

## Ports

Ports must be explicitly listed. Format: `port` or `port/protocol` (default is TCP).

For **reverse mode**, ports are published on the Home Assistant host's network interface, so LAN devices can connect to `http://<HA-IP>:<port>`.

## Troubleshooting

- Check the addon logs for authentication errors
- Ensure your auth key is valid and reusable
- For inject mode, verify the LAN device is reachable from the HA host
- For reverse mode, verify the tailnet IP is correct (check Tailscale admin)
