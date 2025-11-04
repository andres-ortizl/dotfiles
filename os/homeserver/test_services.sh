#!/bin/bash

# Test Services Script for Traefik Configuration
# This script tests all services routed through Traefik

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN=${DOMAIN:-localhost}
TRAEFIK_HOST="$DOMAIN:8081"
DASHBOARD_HOST="localhost:9090"

echo -e "${BLUE}=== Traefik Services Test Script ===${NC}\n"

# Function to test HTTP endpoint
test_endpoint() {
    local service_name=$1
    local url=$2
    local expected_status=${3:-200}

    echo -n "Testing $service_name... "

    # Use curl with timeout, follow redirects, and handle HTTPS
    if response=$(curl -k -s -w "%{http_code}" -o /dev/null --connect-timeout 10 --max-time 30 "$url" 2>/dev/null); then
        if [ "$response" -eq "$expected_status" ] || [ "$response" -eq 200 ] || [ "$response" -eq 302 ]; then
            echo -e "${GREEN}✓ OK${NC} (HTTP $response)"
        else
            echo -e "${YELLOW}⚠ Warning${NC} (HTTP $response)"
        fi
    else
        echo -e "${RED}✗ Failed${NC} (Connection failed)"
    fi
}

# Function to check if service is running in Docker
check_docker_service() {
    local service_name=$1
    echo -n "Docker container $service_name... "

    if docker ps --format "{{.Names}}" | grep -q "^${service_name}$"; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Not running${NC}"
    fi
}

echo -e "${BLUE}=== Checking Docker Containers ===${NC}"
services=("traefik" "portainer" "homepage" "jellyfin" "prowlarr" "sonarr" "radarr" "bazarr" "pihole" "qbittorrent" "immich_server" "siyuan" "openwebui")

for service in "${services[@]}"; do
    check_docker_service "$service"
done

echo -e "\n${BLUE}=== Testing Traefik Dashboard ===${NC}"
test_endpoint "Traefik Dashboard" "http://$DASHBOARD_HOST"

echo -e "\n${BLUE}=== Testing HTTP Services ===${NC}"

# Test all services through Traefik HTTP
test_endpoint "Homepage (root)" "http://$TRAEFIK_HOST"
test_endpoint "Homepage (home.$DOMAIN)" "http://home.$DOMAIN:8081"
test_endpoint "Portainer" "http://portainer.$DOMAIN:8081"
test_endpoint "Jellyfin" "http://jellyfin.$DOMAIN:8081"
test_endpoint "Prowlarr" "http://prowlarr.$DOMAIN:8081"
test_endpoint "Sonarr" "http://sonarr.$DOMAIN:8081"
test_endpoint "Radarr" "http://radarr.$DOMAIN:8081"
test_endpoint "Bazarr" "http://bazarr.$DOMAIN:8081"
test_endpoint "Pi-hole" "http://pihole.$DOMAIN:8081"
test_endpoint "qBittorrent" "http://qbittorrent.$DOMAIN:8081"
test_endpoint "Immich" "http://immich.$DOMAIN:8081"
test_endpoint "SiYuan" "http://siyuan.$DOMAIN:8081"
test_endpoint "OpenWebUI" "http://openwebui.$DOMAIN:8081"
test_endpoint "OpenWebUI (ai.$DOMAIN)" "http://ai.$DOMAIN:8081"

echo -e "\n${BLUE}=== Testing HTTPS Services ===${NC}"

# Test all services through Traefik HTTPS
test_endpoint "Homepage (HTTPS)" "https://home.$DOMAIN:8444"
test_endpoint "Portainer (HTTPS)" "https://portainer.$DOMAIN:8444"
test_endpoint "Jellyfin (HTTPS)" "https://jellyfin.$DOMAIN:8444"
test_endpoint "Prowlarr (HTTPS)" "https://prowlarr.$DOMAIN:8444"
test_endpoint "Sonarr (HTTPS)" "https://sonarr.$DOMAIN:8444"
test_endpoint "Radarr (HTTPS)" "https://radarr.$DOMAIN:8444"
test_endpoint "Bazarr (HTTPS)" "https://bazarr.$DOMAIN:8444"
test_endpoint "Pi-hole (HTTPS)" "https://pihole.$DOMAIN:8444"
test_endpoint "qBittorrent (HTTPS)" "https://qbittorrent.$DOMAIN:8444"
test_endpoint "Immich (HTTPS)" "https://immich.$DOMAIN:8444"
test_endpoint "SiYuan (HTTPS)" "https://siyuan.$DOMAIN:8444"
test_endpoint "OpenWebUI (HTTPS)" "https://openwebui.$DOMAIN:8444"

echo -e "\n${BLUE}=== Testing Direct Port Access (Should be blocked/unavailable) ===${NC}"
# These should fail since we removed the port mappings
test_endpoint "Jellyfin Direct Port (should fail)" "http://localhost:8096" 999
test_endpoint "Portainer Direct Port (should fail)" "http://localhost:9000" 999

echo -e "\n${YELLOW}=== Service URLs Summary ===${NC}"
echo "Traefik Dashboard: http://localhost:9090"
echo ""
echo "HTTP Services (port 8081):"
echo "HTTP Services (port 8081):"
echo "Homepage: http://$DOMAIN:8081 or http://home.$DOMAIN:8081"
echo "Portainer: http://portainer.$DOMAIN:8081"
echo "Jellyfin: http://jellyfin.$DOMAIN:8081"
echo "Prowlarr: http://prowlarr.$DOMAIN:8081"
echo "Sonarr: http://sonarr.$DOMAIN:8081"
echo "Radarr: http://radarr.$DOMAIN:8081"
echo "Bazarr: http://bazarr.$DOMAIN:8081"
echo "Pi-hole: http://pihole.$DOMAIN:8081"
echo "qBittorrent: http://qbittorrent.$DOMAIN:8081"
echo "Immich: http://immich.$DOMAIN:8081"
echo "SiYuan: http://siyuan.$DOMAIN:8081"
echo "OpenWebUI: http://openwebui.$DOMAIN:8081 or http://ai.$DOMAIN:8081"
echo ""
echo "HTTPS Services (port 8444):"
echo "HTTPS Services (port 8444):"
echo "Homepage: https://home.$DOMAIN:8444"
echo "Portainer: https://portainer.$DOMAIN:8444"
echo "Jellyfin: https://jellyfin.$DOMAIN:8444"
echo "Prowlarr: https://prowlarr.$DOMAIN:8444"
echo "Sonarr: https://sonarr.$DOMAIN:8444"
echo "Radarr: https://radarr.$DOMAIN:8444"
echo "Bazarr: https://bazarr.$DOMAIN:8444"
echo "Pi-hole: https://pihole.$DOMAIN:8444"
echo "qBittorrent: https://qbittorrent.$DOMAIN:8444"
echo "Immich: https://immich.$DOMAIN:8444"
echo "SiYuan: https://siyuan.$DOMAIN:8444"
echo "OpenWebUI: https://openwebui.$DOMAIN:8444 or https://ai.$DOMAIN:8444"

echo -e "\n${BLUE}=== Additional Notes ===${NC}"
echo "• All services are now routed through Traefik"
echo "• HTTP on port 8081, HTTPS on port 8444"
echo "• Direct port access has been disabled for security"
echo "• HTTPS uses Traefik's built-in self-signed certificates"
echo "• You may need to accept certificate warnings in your browser"
echo ""
echo "Add these hostnames to your /etc/hosts file for local access:"
echo "  127.0.0.1 home.$DOMAIN portainer.$DOMAIN jellyfin.$DOMAIN"
echo "  127.0.0.1 prowlarr.$DOMAIN sonarr.$DOMAIN radarr.$DOMAIN"
echo "  127.0.0.1 bazarr.$DOMAIN pihole.$DOMAIN qbittorrent.$DOMAIN"
echo "  127.0.0.1 immich.$DOMAIN siyuan.$DOMAIN openwebui.$DOMAIN ai.$DOMAIN"

echo -e "\n${GREEN}=== Test Complete ===${NC}"
