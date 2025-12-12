#!/usr/bin/env bash
#
# Test RELEASE images from docker.io for connector-admin (includes platform-registration-service)
# 
# Usage:
#   ./test-connector-admin-release.sh [VERSION]
#   
# Examples:
#   ./test-connector-admin-release.sh                    # Uses latest release
#   ./test-connector-admin-release.sh 1.0.0             # Test specific version

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_COMPOSE="${SCRIPT_DIR}/docker-compose.yml"
PLATFORM_REG_COMPOSE="${SCRIPT_DIR}/services/platform-registration-service/docker-compose.yml"
PLATFORM_REG_RELEASE="${SCRIPT_DIR}/services/platform-registration-service/docker-compose.release.yml"
CONNECTOR_ADMIN_COMPOSE="${SCRIPT_DIR}/services/connector-admin/docker-compose.yml"
CONNECTOR_ADMIN_RELEASE="${SCRIPT_DIR}/services/connector-admin/docker-compose.release.yml"
SERVICE_DIR="${SCRIPT_DIR}/services/connector-admin"

# Accept VERSION as first argument or environment variable
VERSION=${1:-${VERSION:-latest}}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

cleanup() {
    log_info "Cleaning up containers..."
    docker compose -f "${BASE_COMPOSE}" \
        -f "${PLATFORM_REG_COMPOSE}" -f "${PLATFORM_REG_RELEASE}" \
        -f "${CONNECTOR_ADMIN_COMPOSE}" -f "${CONNECTOR_ADMIN_RELEASE}" \
        --env-file <(echo "VERSION=${VERSION}") \
        down -v --remove-orphans 2>/dev/null || true
}

# Validate compose files exist
if [ ! -f "${BASE_COMPOSE}" ]; then
    log_error "Base compose file not found: ${BASE_COMPOSE}"
    exit 1
fi

if [ ! -f "${PLATFORM_REG_COMPOSE}" ]; then
    log_error "Platform registration compose file not found: ${PLATFORM_REG_COMPOSE}"
    exit 1
fi

if [ ! -f "${PLATFORM_REG_RELEASE}" ]; then
    log_error "Platform registration release override not found: ${PLATFORM_REG_RELEASE}"
    exit 1
fi

if [ ! -f "${CONNECTOR_ADMIN_COMPOSE}" ]; then
    log_error "Connector admin compose file not found: ${CONNECTOR_ADMIN_COMPOSE}"
    exit 1
fi

if [ ! -f "${CONNECTOR_ADMIN_RELEASE}" ]; then
    log_error "Connector admin release override not found: ${CONNECTOR_ADMIN_RELEASE}"
    exit 1
fi

# Main test execution
main() {
    log_info "Starting Connector Admin Release Integration Tests"
    log_info "Testing version: ${VERSION}"
    log_info "Images:"
    log_info "  - docker.io/pipestreamai/platform-registration-service:${VERSION}"
    log_info "  - docker.io/pipestreamai/connector-admin:${VERSION}"
    
    # Ensure clean state
    cleanup
    
    # Start all services (infrastructure + platform-registration-service + connector-admin)
    log_info "Starting infrastructure and services..."
    VERSION="${VERSION}" docker compose \
        -f "${BASE_COMPOSE}" \
        -f "${PLATFORM_REG_COMPOSE}" \
        -f "${PLATFORM_REG_RELEASE}" \
        -f "${CONNECTOR_ADMIN_COMPOSE}" \
        -f "${CONNECTOR_ADMIN_RELEASE}" \
        --env-file <(echo "VERSION=${VERSION}") \
        up -d
    
    # Wait for infrastructure services
    log_info "Waiting for infrastructure services to be healthy..."
    sleep 10
    
    # Wait for platform-registration-service to be ready
    log_test "Waiting for platform-registration-service to be ready..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf --max-time 5 "http://localhost:38201/platform-registration/q/health/ready" > /dev/null 2>&1; then
            log_info "platform-registration-service is ready!"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "platform-registration-service did not become ready within ${max_attempts} attempts"
            docker logs platform-registration-service --tail 50
            cleanup
            exit 1
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo ""
    
    # Wait for connector-admin to be ready
    log_test "Waiting for connector-admin to be ready..."
    attempt=1
    max_attempts=90
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf --max-time 5 "http://localhost:38107/connector/q/health/ready" > /dev/null 2>&1; then
            log_info "connector-admin is ready!"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "connector-admin did not become ready within ${max_attempts} attempts"
            docker logs connector-admin --tail 50
            cleanup
            exit 1
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo ""
    
    # Run service-specific tests
    if [ -f "${SERVICE_DIR}/test.sh" ]; then
        log_test "Running connector-admin integration tests..."
        cd "${SERVICE_DIR}"
        if ./test.sh; then
            log_info "Connector-admin integration tests passed!"
        else
            log_error "Connector-admin integration tests failed!"
            cleanup
            exit 1
        fi
        cd - > /dev/null
    else
        log_warn "Service test script not found: ${SERVICE_DIR}/test.sh"
    fi
    
    # Print summary
    echo ""
    log_info "=== Test Summary ==="
    docker compose -f "${BASE_COMPOSE}" \
        -f "${PLATFORM_REG_COMPOSE}" -f "${PLATFORM_REG_RELEASE}" \
        -f "${CONNECTOR_ADMIN_COMPOSE}" -f "${CONNECTOR_ADMIN_RELEASE}" \
        --env-file <(echo "VERSION=${VERSION}") \
        ps
    
    log_info ""
    log_info "=== Release Tests Passed! ==="
    log_info "Services are running:"
    log_info "  - platform-registration-service: http://localhost:38201 (gRPC: localhost:38201)"
    log_info "  - connector-admin: http://localhost:38107 (gRPC: localhost:38107)"
    log_info ""
    log_info "To test gRPC:"
    log_info "  grpcurl -plaintext localhost:38201 list"
    log_info "  grpcurl -plaintext localhost:38107 list"
    log_info ""
    log_info "To stop and clean up:"
    log_info "  docker compose -f ${BASE_COMPOSE} -f ${PLATFORM_REG_COMPOSE} -f ${PLATFORM_REG_RELEASE} -f ${CONNECTOR_ADMIN_COMPOSE} -f ${CONNECTOR_ADMIN_RELEASE} --env-file <(echo \"VERSION=${VERSION}\") down -v"
    log_info ""
    log_warn "Containers are still running. Run cleanup manually or use Ctrl+C to trigger cleanup."
}

# Handle script interruption
trap cleanup EXIT INT TERM

# Run main function
main "$@"
