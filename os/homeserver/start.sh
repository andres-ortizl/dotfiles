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
