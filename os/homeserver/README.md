# Homeserver Stack

Docker compose setup for home lab services.

## Quick Start

```bash
git clone <repo>
cd os/homeserver
cp .env.example .env
nano .env  # Configure your settings
docker compose up -d
```

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Homepage | http://home.lab.lan | Dashboard |
| Portainer | http://portainer.lab.lan | Container management |
| Jellyfin | http://jellyfin.lab.lan | Media server |
| Immich | http://immich.lab.lan | Photo management |
| Pi-hole | http://pihole.lab.lan | DNS & ad blocking |
| OpenWebUI | http://openwebui.lab.lan | AI chat interface |
| Traefik | http://192.168.1.193:9090 | Reverse proxy dashboard |
| Home Assistant | http://192.168.1.193:8123 | Smart home hub |

Full service list: Prowlarr, Sonarr, Radarr, Bazarr, qBittorrent, Excalidraw

## Configuration

1. **Update IP in Pi-hole configs** if your NAS IP differs from `192.168.1.193`
2. **Set DOMAIN in .env** (default: `lab.lan`)
3. **Configure Pi-hole as your DNS server** in router DHCP settings

## Management

```bash
# View logs
docker compose logs -f [service]

# Restart service
docker compose restart [service]

# Update all services
docker compose pull && docker compose up -d

# Stop everything
docker compose down
```

## Pi-hole DNS Setup

Pi-hole provides wildcard DNS for `*.lab.lan` → NAS IP.

After updating DNS configs:
```bash
docker exec pihole pihole restartdns
```

## Notes

- NAS admin: http://lab.lan:9999
- All services use Traefik reverse proxy (ports 80/443)
- Home Assistant uses host network mode (direct access on port 8123)