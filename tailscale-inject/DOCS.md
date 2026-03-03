# Tailscale Inject

Expose LAN devices as individual Tailscale nodes with per-device ACLs and sharing.

## What It Does

Each configured device gets its own Tailscale container with a unique node identity. This means:

- **Per-device ACLs** — control access to each device independently in Tailscale admin
- **Node sharing** — share individual devices with friends via Tailscale's sharing feature
- **Clean separation** — each device appears as its own node in your tailnet

## Configuration

### Auth Key

Generate a reusable auth key in the [Tailscale admin console](https://login.tailscale.com/admin/settings/keys). Set it as the global `auth_key`, or per-device if you need different keys.

### Devices

Each device needs:
- **name**: Becomes the Tailscale hostname and must be unique
- **target**: The LAN device to forward to — accepts an IP address (`192.168.178.50`), hostname (`printer.local`), or MAC address (`aa:bb:cc:dd:ee:ff`)
- **ports**: List of ports to forward (e.g., `631`, `9100/tcp`, `5353/udp`)
- **auth_key** (optional): Override the global auth key for this device

### Example

```yaml
auth_key: "tskey-auth-abc123..."
devices:
  - name: "home-printer"
    target: "192.168.178.50"
    ports:
      - "631"
      - "9100/tcp"

  - name: "denon-avr"
    target: "Denon-AVR-X2600H.local"
    ports:
      - "80"
      - "443"
```

## How It Works

The addon spawns one Docker container per device using Docker Compose. Each container:
1. Runs Tailscale in userspace mode (no kernel module needed)
2. Authenticates with the provided auth key
3. Uses socat to forward ports from the tailnet to the LAN device

Tailscale state is stored in named Docker volumes, so authentication persists across restarts.

## Ports

Ports must be explicitly listed. Format: `port` or `port/protocol` (default is TCP).

## Target Resolution

- **IP address** — used directly
- **Hostname** — resolved via DNS/mDNS at startup
- **MAC address** — resolved via ARP scan at startup

## Troubleshooting

- Check the addon logs for authentication errors
- Ensure your auth key is valid and reusable
- Verify the LAN device is reachable from the HA host
- For MAC address targets, the device must be powered on and on the same subnet
