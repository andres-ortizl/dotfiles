# Debugging Homeserver Services - Initial Prompt Template

## Setup Overview

I have a homeserver running on a Synology NAS with Docker services managed through my dotfiles repository.

**Local Machine:**
- OS: Linux (Arch-based)
- Username: andres
- Dotfiles Location: `/home/andres/code/dotfiles`
- Homeserver Config: `dotfiles/os/homeserver/`

**Remote NAS:**
- IP Address: `192.168.1.193`
- SSH User: `andrew`
- Docker Compose Location: `/volume1/docker/nasito-deploy/`
- Hostname: `nasito` (accessible as `nasito:9999` for NAS admin)
- Domain: `nasito.local` (managed by Pi-hole DNS)
- Reverse Proxy: Traefik on port `8081` (HTTP) and `8444` (HTTPS)
- Direct Traefik Dashboard: `http://192.168.1.193:9090/dashboard/`

## Infrastructure

**Network Setup:**
- Router configured to use Pi-hole (192.168.1.193:53) as primary DNS
- Local machine DNS configured to use Pi-hole
- All services accessible via `http://service.nasito.local:8081`

**Docker Compose Services:**
- **Traefik** (v3.0) - Reverse proxy and load balancer
- **Pi-hole** (2024.07.0) - DNS server and ad-blocker (port 53)
- **Homepage** (v1.5.0) - Service dashboard
- **Portainer** (2.21.1) - Docker management
- **Jellyfin** (10.10.1) - Media server
- **Immich** - Photo and video management
- **OpenWebUI** (v0.3.35) - AI chat interface
- **Siyuan** (v3.1.17) - Note-taking application
- **Excalidraw** - Collaborative whiteboard
- **Sonarr** (4.0.10) - TV show automation
- **Radarr** (5.12.2) - Movie automation
- **Prowlarr** (1.28.2) - Indexer manager
- **Bazarr** (1.4.5) - Subtitle automation
- **qBittorrent** (5.0.2) - Torrent client
- **Watchtower** (1.7.1) - Auto-updater

## File Structure

```
dotfiles/
├── os/
│   └── homeserver/
│       ├── docker-compose.yml          # Main service definitions
│       ├── .env.example                # Environment variables template
│       ├── .gitignore                  # Git ignore rules
│       ├── deploy.sh                   # Deployment script
│       ├── start.sh / stop.sh          # Service control
│       ├── homepage/
│       │   ├── services.yaml           # Service definitions
│       │   ├── settings.yaml           # Homepage settings
│       │   ├── docker.yaml             # Docker integration
│       │   ├── bookmarks.yaml          # Bookmarks
│       │   └── custom.css              # Catppuccin theme CSS
│       ├── pihole/
│       │   ├── custom.list             # Local DNS records
│       │   ├── adlists.list            # Ad blocking lists
│       │   ├── whitelist.txt           # Whitelisted domains
│       │   └── regex.list              # Regex filters
│       ├── jellyfin/
│       ├── immich/
│       ├── openwebui/
│       ├── qbittorrent/
│       ├── portainer/
│       └── siyuan/
```

## Standard Workflow

### 1. Editing Files Locally

Edit configuration files in `dotfiles/os/homeserver/` on local machine.

### 2. Copying Files to NAS

**Docker Compose:**
```bash
cat os/homeserver/docker-compose.yml | ssh andrew@192.168.1.193 "cat > /volume1/docker/nasito-deploy/docker-compose.yml"
```

**Service-specific configs:**
```bash
# Homepage
cat os/homeserver/homepage/services.yaml | ssh andrew@192.168.1.193 "cat > /volume1/docker/nasito-deploy/homepage/services.yaml"

# Pi-hole DNS
cat os/homeserver/pihole/custom.list | ssh andrew@192.168.1.193 "cat > /volume1/docker/nasito-deploy/pihole/custom.list"
```

### 3. Applying Changes

**Restart specific service:**
```bash
ssh andrew@192.168.1.193 "cd /volume1/docker/nasito-deploy && docker compose up -d <service-name>"
```

**Restart entire stack:**
```bash
ssh andrew@192.168.1.193 "cd /volume1/docker/nasito-deploy && docker compose up -d"
```

**Reload Pi-hole DNS:**
```bash
ssh andrew@192.168.1.193 "docker exec pihole pihole restartdns reload"
# or
ssh andrew@192.168.1.193 "docker restart pihole"
```

## Common Debugging Commands

**Check service status:**
```bash
ssh andrew@192.168.1.193 "docker ps"
ssh andrew@192.168.1.193 "docker ps | grep <service-name>"
```

**View logs:**
```bash
ssh andrew@192.168.1.193 "docker logs <service-name> --tail 50"
ssh andrew@192.168.1.193 "docker logs <service-name> --follow"
```

**Restart service:**
```bash
ssh andrew@192.168.1.193 "docker restart <service-name>"
```

**Check Traefik routes:**
```bash
curl -s http://192.168.1.193:9090/api/http/routers | python3 -m json.tool | grep -A 10 "<service>"
```

**Test DNS resolution:**
```bash
dig @192.168.1.193 service.nasito.local +short
nslookup service.nasito.local 192.168.1.193
```

**Test service connectivity:**
```bash
curl -I http://service.nasito.local:8081
curl -I http://192.168.1.193:8081 -H "Host: service.nasito.local"
```

**Check container environment:**
```bash
ssh andrew@192.168.1.193 "docker exec <service-name> env"
```

## DNS Configuration

Pi-hole manages local DNS records in `pihole/custom.list`:

**Format:**
```
192.168.1.193 service.nasito.local
192.168.1.193 service.local
```

**Current Records:**
- nasito.local → 192.168.1.193
- All services: `<service>.nasito.local` → 192.168.1.193
- Legacy `.local` domains for backward compatibility

**After updating DNS:**
1. Copy `custom.list` to NAS
2. Reload Pi-hole: `docker exec pihole pihole restartdns reload`
3. May need to restart Pi-hole container if reload doesn't work

## Traefik Configuration

**Service Labels Pattern:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.service-name.rule=Host(`service.${DOMAIN:-localhost}`)"
  - "traefik.http.routers.service-name.entrypoints=web"
  - "traefik.http.routers.service-name-secure.rule=Host(`service.${DOMAIN:-localhost}`)"
  - "traefik.http.routers.service-name-secure.entrypoints=websecure"
  - "traefik.http.routers.service-name-secure.tls=true"
  - "traefik.http.services.service-name.loadbalancer.server.port=8080"
```

**Accessing Services:**
- Through Traefik: `http://service.nasito.local:8081`
- Direct access (if port exposed): `http://192.168.1.193:<port>`

## Known Issues and Solutions

### Homepage Host Validation
Homepage requires explicit allowed hosts:
```yaml
environment:
  - HOMEPAGE_ALLOWED_HOSTS=home.${DOMAIN:-localhost}:8081,${DOMAIN:-localhost}:8081,home.${DOMAIN:-localhost},${DOMAIN:-localhost},*
```

### Traefik Dashboard Routing
Traefik's own dashboard needs special service configuration:
```yaml
- "traefik.http.routers.dashboard.service=api@internal"
```

### Siyuan Access Code
Siyuan requires `--accessAuthCode` parameter:
```yaml
command:
  - "--workspace=/siyuan/workspace/"
  - "--accessAuthCode=${SIYUAN_ACCESS_AUTH_CODE:-123456}"
```

### Portainer Timeout
Portainer has 5-minute security timeout for initial setup. Restart if timed out:
```bash
ssh andrew@192.168.1.193 "docker restart portainer"
```

### DNS Not Resolving
1. Check Pi-hole is running: `docker ps | grep pihole`
2. Verify DNS entry exists: `grep service /volume1/docker/nasito-deploy/pihole/custom.list`
3. Reload DNS: `docker exec pihole pihole restartdns reload`
4. Check local machine is using Pi-hole: `cat /etc/resolv.conf`
5. Test direct query: `dig @192.168.1.193 service.nasito.local +short`

## Environment Variables

Key variables in `.env` file (not tracked in git):
- `DOMAIN=nasito.local` - Base domain for services
- `PUID=1000` / `PGID=1000` - User/group IDs
- `TZ=Europe/Madrid` - Timezone
- Service-specific passwords and API keys

## Current Issue

**Service:** [NAME]

**URL:** http://[service].nasito.local:8081

**Problem Description:**
[Describe the issue you're experiencing]

**Error Message/Behavior:**
[Paste error messages or describe unexpected behavior]

**What I've Tried:**
1. [Action taken]
2. [Another action]
3. [etc.]

**Relevant Logs:**
```
[Paste relevant log output]
```

**Additional Context:**
[Any other relevant information]

---

**Question:** Can you help me debug this issue?