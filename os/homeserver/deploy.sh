#!/bin/bash

# Nasito Deployment Script
# Creates a clean deployment package ready for upload to your server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_DIR="nasito-deploy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=== Nasito Deployment Package Generator ===${NC}\n"

# Clean up existing deploy directory
if [ -d "$DEPLOY_DIR" ]; then
    echo -e "${YELLOW}Removing existing deployment directory...${NC}"
    rm -rf "$DEPLOY_DIR"
fi

# Create deployment directory structure
echo -e "${BLUE}Creating deployment structure...${NC}"
mkdir -p "$DEPLOY_DIR"

# Copy essential files
echo -e "${BLUE}Copying configuration files...${NC}"
cp docker-compose.yml "$DEPLOY_DIR/"
cp test_services.sh "$DEPLOY_DIR/"

# Copy domain configuration if it exists
if [ -f "DOMAIN_CONFIG.md" ]; then
    cp DOMAIN_CONFIG.md "$DEPLOY_DIR/"
fi

# Make scripts executable
chmod +x "$DEPLOY_DIR/test_services.sh"

# Create directory structure for volumes
echo -e "${BLUE}Creating volume directories...${NC}"
mkdir -p "$DEPLOY_DIR"/{homepage,jellyfin/config,portainer,pihole,qbittorrent/config,immich,siyuan,openwebui}
# Copy files using gitignore patterns to exclude data/cache/logs
echo -e "${BLUE}Copying project files (excluding data directories)...${NC}"

# Use rsync to copy files while respecting .gitignore patterns
if command -v rsync >/dev/null 2>&1; then
    echo "  Using rsync with .gitignore patterns..."
    rsync -av \
        --exclude-from='.gitignore' \
        --exclude='.git/' \
        --exclude="$DEPLOY_DIR/" \
        --exclude='nasito-deploy.tar.gz' \
        --exclude='*.tar.gz' \
        ./ "$DEPLOY_DIR/"
else
    echo "  rsync not found, using manual copy method..."
    # Fallback: Copy essential files manually

    # Create volume directories
    mkdir -p "$DEPLOY_DIR"/{homepage,jellyfin/config,portainer,pihole,qbittorrent/config,immich,siyuan,openwebui}
    mkdir -p "$DEPLOY_DIR/jellyfin/config"/{prowlarr,sonarr,radarr,bazarr}
    mkdir -p "$DEPLOY_DIR/pihole"/{etc-pihole,etc-dnsmasq.d}

    # Copy configuration files only
    echo "  Copying service configurations..."

    # Homepage config (exclude logs and generated files)
    if [ -f "homepage/settings.yaml" ]; then
        cp homepage/settings.yaml "$DEPLOY_DIR/homepage/"
    fi

    # Pi-hole configuration files
    if [ -d "pihole" ]; then
        echo "    Copying Pi-hole config..."
        [ -f "pihole/custom.list" ] && cp pihole/custom.list "$DEPLOY_DIR/pihole/"
        [ -f "pihole/adlists.list" ] && cp pihole/adlists.list "$DEPLOY_DIR/pihole/"
        [ -f "pihole/whitelist.txt" ] && cp pihole/whitelist.txt "$DEPLOY_DIR/pihole/"
        [ -f "pihole/regex.list" ] && cp pihole/regex.list "$DEPLOY_DIR/pihole/"
    fi

    # Copy specific config files for other services (avoiding data directories)
    for service in jellyfin qbittorrent immich siyuan openwebui; do
        if [ -d "$service" ]; then
            echo "    Copying $service config files..."
            find "$service" -type f \( -name "*.conf" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.xml" \) \
                ! -path "*/data/*" ! -path "*/cache/*" ! -path "*/logs/*" ! -path "*/config/*" 2>/dev/null | \
            while read file; do
                mkdir -p "$DEPLOY_DIR/$(dirname "$file")"
                cp "$file" "$DEPLOY_DIR/$file" 2>/dev/null || true
            done
        fi
    done
fi

# Create example environment file
echo -e "${BLUE}Creating configuration files...${NC}"
cat > "$DEPLOY_DIR/.env.example" << 'EOF'
# Nasito Configuration
# Copy this file to .env and adjust the values for your setup

# Domain Configuration
# Default: localhost (services accessible as service.localhost:8081)
# Examples: local, home.lan, mynas.local, etc.
DOMAIN=localhost

# User and Group IDs (run 'id' command to get your values)
PUID=1000
PGID=1000

# Timezone
TZ=Europe/Madrid

# Storage Paths (adjust to your server paths)
MEDIA_ROOT=./media
DOWNLOADS_ROOT=./downloads
CACHE_ROOT=./cache
UPLOAD_LOCATION=./immich/upload

# Database Configuration (Immich)
DB_PASSWORD=postgres
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
DB_DATA_LOCATION=./immich/postgres

# Service Configuration
QBITTORRENT_USERNAME=admin
QBITTORRENT_PASSWORD=adminpass

# Pi-hole Configuration
PIHOLE_PASSWORD=admin
PIHOLE_DNS=1.1.1.1;1.0.0.1

# SiYuan Configuration
SIYUAN_ACCESS_AUTH_CODE=123456

# OpenWebUI Configuration (if using local Ollama)
OLLAMA_BASE_URL=http://host.docker.internal:11434

# Immich Version
IMMICH_VERSION=release

# API Keys (generate these in the respective applications after first setup)
SONARR_API_KEY=
RADARR_API_KEY=
EOF

# Create README for deployment
cat > "$DEPLOY_DIR/README.md" << 'EOF'
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
EOF

# Create startup script
cat > "$DEPLOY_DIR/start.sh" << 'EOF'
#!/bin/bash

# Nasito Startup Script
echo "Starting Nasito services..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "Warning: .env file not found. Copying from .env.example"
    cp .env.example .env
    echo "Please edit .env file with your configuration and run this script again."
    exit 1
fi

# Start services
docker-compose up -d

echo "Services started! Access your dashboard at:"
echo "  http://$(hostname -I | awk '{print $1}'):8081"
echo ""
echo "Run './test_services.sh' to verify all services are working."
EOF

# Create stop script
cat > "$DEPLOY_DIR/stop.sh" << 'EOF'
#!/bin/bash

# Nasito Stop Script
echo "Stopping Nasito services..."
docker-compose down
echo "All services stopped."
EOF

# Make scripts executable
chmod +x "$DEPLOY_DIR/start.sh"
chmod +x "$DEPLOY_DIR/stop.sh"

# Create update script
cat > "$DEPLOY_DIR/update.sh" << 'EOF'
#!/bin/bash

# Nasito Update Script
echo "Updating Nasito services..."

# Pull latest images
docker-compose pull

# Restart services with new images
docker-compose up -d

echo "Services updated and restarted!"
echo "Run './test_services.sh' to verify everything is working."
EOF

chmod +x "$DEPLOY_DIR/update.sh"

# Create .gitignore for the deployment
cat > "$DEPLOY_DIR/.gitignore" << 'EOF'
# Environment file (contains sensitive data)
.env

# Volume data directories
*/
!.gitkeep

# Logs
*.log

# Temporary files
*.tmp
.DS_Store
EOF

# Create gitkeep files to preserve directory structure
find "$DEPLOY_DIR" -type d -empty -exec touch {}/.gitkeep \;

# Create archive automatically
echo -e "${BLUE}Creating archive...${NC}"
tar -czf "$DEPLOY_DIR.tar.gz" "$DEPLOY_DIR"

# Summary
echo -e "\n${GREEN}=== Deployment Package Created Successfully! ===${NC}\n"
echo -e "${YELLOW}Package folder:${NC} $(pwd)/$DEPLOY_DIR"
echo -e "${YELLOW}Package archive:${NC} $(pwd)/$DEPLOY_DIR.tar.gz"
echo -e "${YELLOW}Archive size:${NC} $(du -sh "$DEPLOY_DIR.tar.gz" | cut -f1)"

echo -e "\n${BLUE}Package contents:${NC}"
echo "📁 Configuration files:"
echo "  ├── docker-compose.yml     (Main service configuration)"
echo "  ├── .env.example          (Environment template)"
echo "  └── DOMAIN_CONFIG.md      (Domain setup guide)"
echo ""
echo "📁 Management scripts:"
echo "  ├── start.sh              (Start all services)"
echo "  ├── stop.sh               (Stop all services)"
echo "  ├── update.sh             (Update all services)"
echo "  └── test_services.sh      (Test service connectivity)"
echo ""
echo "📁 Volume directories:"
echo "  └── [Pre-created service directories]"

echo -e "\n${BLUE}Upload options:${NC}"
echo "1. Upload folder: ${YELLOW}$DEPLOY_DIR/${NC}"
echo "2. Upload archive: ${YELLOW}$DEPLOY_DIR.tar.gz${NC} (recommended)"

echo -e "\n${BLUE}Next steps on your server:${NC}"
echo "1. Upload and extract: ${YELLOW}tar -xzf $DEPLOY_DIR.tar.gz${NC}"
echo "2. Navigate to folder: ${YELLOW}cd $DEPLOY_DIR${NC}"
echo "3. Copy configuration: ${YELLOW}cp .env.example .env${NC}"
echo "4. Edit configuration: ${YELLOW}nano .env${NC}"
echo "5. Start services: ${YELLOW}./start.sh${NC}"
echo "6. Test deployment: ${YELLOW}./test_services.sh${NC}"

echo -e "\n${GREEN}Deployment package ready! 🚀${NC}"
echo -e "${YELLOW}Note:${NC} Original project structure preserved in current directory"
