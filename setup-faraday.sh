#!/bin/bash

# Faraday Vulnerability Management Platform Setup Script
# This script automates the installation of Faraday using Docker

set -e  # Exit on any error

echo "🚀 Starting Faraday Setup..."
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
check_docker() {
    print_status "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_status "Docker is installed and running."
}

# Check if ports are available
check_ports() {
    print_status "Checking if required ports are available..."
    
    local ports=(5985 5432 6379)
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep ":$port " > /dev/null; then
            print_warning "Port $port is already in use. This might cause issues."
        fi
    done
}

# Clean up existing containers
cleanup_existing() {
    print_status "Cleaning up existing containers..."
    
    # Stop and remove existing containers
    docker stop faraday_app faraday_postgres faraday_redis 2>/dev/null || true
    docker rm faraday_app faraday_postgres faraday_redis 2>/dev/null || true
    
    # Remove existing network
    docker network rm faraday_network 2>/dev/null || true
    
    # Remove old configuration
    if [ -d "$HOME/.faraday" ]; then
        print_status "Removing old configuration..."
        sudo rm -rf "$HOME/.faraday" 2>/dev/null || true
    fi
}

# Create Docker network
create_network() {
    print_status "Creating Docker network..."
    docker network create faraday_network
}

# Start PostgreSQL
start_postgres() {
    print_status "Starting PostgreSQL database..."
    docker run -d --name faraday_postgres \
        --network faraday_network \
        -e POSTGRES_USER=postgres \
        -e POSTGRES_PASSWORD=postgres \
        -e POSTGRES_DB=faraday \
        -p 5432:5432 \
        postgres:12.7-alpine
    
    print_status "Waiting for PostgreSQL to be ready..."
    sleep 10
}

# Start Redis
start_redis() {
    print_status "Starting Redis cache..."
    docker run -d --name faraday_redis \
        --network faraday_network \
        -p 6379:6379 \
        redis:6.2-alpine
}

# Start Faraday application
start_faraday() {
    print_status "Starting Faraday application..."
    docker run -d --name faraday_app \
        --network faraday_network \
        -v "$HOME/.faraday:/home/faraday/.faraday" \
        -p 5985:5985 \
        -e PGSQL_USER=postgres \
        -e PGSQL_HOST=faraday_postgres \
        -e PGSQL_PASSWD=postgres \
        -e PGSQL_DBNAME=faraday \
        -e REDIS_SERVER=faraday_redis \
        --entrypoint="/entrypoint.sh" \
        faradaysec/faraday:latest
    
    print_status "Waiting for Faraday to initialize..."
    sleep 30
}

# Set up default password
setup_password() {
    print_status "Setting up default password..."
    sleep 10  # Wait a bit more for the application to be ready
    
    docker exec faraday_app python3 -m faraday.manage change-password \
        --username faraday \
        --password "Faraday123!" 2>/dev/null || print_warning "Could not set password. You may need to set it manually."
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Check if containers are running
    if docker ps | grep -q faraday_app; then
        print_status "Faraday application is running."
    else
        print_error "Faraday application is not running."
        return 1
    fi
    
    # Test web interface
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5985 | grep -q "200"; then
        print_status "Web interface is accessible."
    else
        print_warning "Web interface might not be ready yet. Please wait a few minutes."
    fi
}

# Display final information
show_final_info() {
    echo ""
    echo "🎉 Faraday Setup Complete!"
    echo "================================"
    echo ""
    echo "📊 Container Status:"
    docker ps | grep faraday
    echo ""
    echo "🌐 Access Faraday:"
    echo "   URL: http://localhost:5985"
    echo ""
    echo "🔐 Login Credentials:"
    echo "   Username: faraday"
    echo "   Password: Faraday123!"
    echo ""
    echo "📋 Useful Commands:"
    echo "   View logs: docker logs faraday_app"
    echo "   Stop services: docker stop faraday_app faraday_postgres faraday_redis"
    echo "   Start services: docker start faraday_postgres faraday_redis faraday_app"
    echo "   Change password: docker exec faraday_app python3 -m faraday.manage change-password --username faraday --password NEW_PASSWORD"
    echo ""
    echo "📚 Documentation:"
    echo "   README.md - Complete setup and troubleshooting guide"
    echo ""
    echo "Happy Vulnerability Management! 🛡️"
}

# Main execution
main() {
    echo "Faraday Vulnerability Management Platform Setup"
    echo "=============================================="
    echo ""
    
    check_docker
    check_ports
    cleanup_existing
    create_network
    start_postgres
    start_redis
    start_faraday
    setup_password
    verify_installation
    show_final_info
}

# Run main function
main "$@" 
