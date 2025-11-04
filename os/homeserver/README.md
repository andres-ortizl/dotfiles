# Nasito Deployment Package

This package contains everything needed to deploy your Nasito media server stack.

## Quick Start

1. **Upload this entire folder to your server**
2. **Configure environment**:
   ```bash
   cp .env.example .env
   nano .env  # Edit with your settings
   ```
3. **Start services**:
   ```bash
   docker-compose up -d
   ```
4. **Test deployment**:
   ```bash
   ./test_services.sh
   ```

## Default Access URLs

- **Traefik Dashboard**: http://your-server-ip:9090
- **Homepage**: http://your-server-ip:8081 or http://home.localhost:8081
- **All Services**: http://service.localhost:8081 (replace with your domain)

## Services Included

| Service | Description | Default URL |
|---------|-------------|-------------|
| Homepage | Dashboard | http://home.localhost:8081 |
| Portainer | Container Management | http://portainer.localhost:8081 |
| Jellyfin | Media Server | http://jellyfin.localhost:8081 |
| Prowlarr | Indexer Management | http://prowlarr.localhost:8081 |
| Sonarr | TV Series | http://sonarr.localhost:8081 |
| Radarr | Movies | http://radarr.localhost:8081 |
| Bazarr | Subtitles | http://bazarr.localhost:8081 |
| qBittorrent | Downloads | http://qbittorrent.localhost:8081 |
| Pi-hole | DNS/Ad Blocker | http://pihole.localhost:8081 |
| Immich | Photos | http://immich.localhost:8081 |
| SiYuan | Notes | http://siyuan.localhost:8081 |
| OpenWebUI | AI Chat | http://openwebui.localhost:8081 |

## HTTPS Access

All services are also available via HTTPS on port 8444:
- Example: https://jellyfin.localhost:8444

## Custom Domains

See `DOMAIN_CONFIG.md` for detailed instructions on setting up custom domains.

## Port Configuration

- **8081**: HTTP access to all services
- **8444**: HTTPS access to all services
- **9090**: Traefik dashboard (always localhost)

## Directory Structure

```
nasito-deploy/
├── docker-compose.yml     # Main configuration
├── .env.example          # Environment template
├── test_services.sh      # Service testing script
├── DOMAIN_CONFIG.md      # Domain configuration guide
├── README.md            # This file
└── [service-folders]/   # Volume directories
```

## First Time Setup

1. **Configure Storage**: Edit paths in `.env` to match your server
2. **Set Permissions**: Ensure PUID/PGID match your user
3. **Update Passwords**: Change default passwords in `.env`
4. **Configure DNS**: Add hostname entries if using custom domains

## Maintenance

- **View logs**: `docker-compose logs [service-name]`
- **Update services**: `docker-compose pull && docker-compose up -d`
- **Restart service**: `docker-compose restart [service-name]`
- **Test services**: `./test_services.sh`

## Troubleshooting

- **Port conflicts**: Check if ports 8081, 8444, 9090 are available
- **Permission issues**: Verify PUID/PGID in `.env` match your user
- **Service not accessible**: Run `./test_services.sh` to diagnose
- **Domain issues**: See `DOMAIN_CONFIG.md` for DNS configuration

For more help, check the logs: `docker-compose logs`
