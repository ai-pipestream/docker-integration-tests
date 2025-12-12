#!/usr/bin/env bash
#
# Test SNAPSHOT images from GHCR for connector-admin (includes platform-registration-service)
# 
# Usage:
#   ./test-connector-admin-snapshot.sh [GITHUB_SHA]
#   
# Examples:
#   ./test-connector-admin-snapshot.sh                    # Uses latest snapshot
#   ./test-connector-admin-snapshot.sh abc1234            # Test specific snapshot by SHA
#   ./test-connector-admin-snapshot.sh main-abc1234       # Test branch-specific snapshot

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_COMPOSE="${SCRIPT_DIR}/docker-compose.yml"
PLATFORM_REG_COMPOSE="${SCRIPT_DIR}/services/platform-registration-service/docker-compose.yml"
PLATFORM_REG_SNAPSHOT="${SCRIPT_DIR}/services/platform-registration-service/docker-compose.snapshot.yml"
CONNECTOR_ADMIN_COMPOSE="${SCRIPT_DIR}/services/connector-admin/docker-compose.yml"
CONNECTOR_ADMIN_SNAPSHOT="${SCRIPT_DIR}/services/connector-admin/docker-compose.snapshot.yml"
SERVICE_DIR="${SCRIPT_DIR}/services/connector-admin"

# Accept GITHUB_SHA as first argument or environment variable
GITHUB_SHA=${1:-${GITHUB_SHA:-latest}}

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
        -f "${PLATFORM_REG_COMPOSE}" -f "${PLATFORM_REG_SNAPSHOT}" \
        -f "${CONNECTOR_ADMIN_COMPOSE}" -f "${CONNECTOR_ADMIN_SNAPSHOT}" \
        --env-file <(echo "GITHUB_SHA=${GITHUB_SHA}") \
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

if [ ! -f "${PLATFORM_REG_SNAPSHOT}" ]; then
    log_error "Platform registration snapshot override not found: ${PLATFORM_REG_SNAPSHOT}"
    exit 1
fi

if [ ! -f "${CONNECTOR_ADMIN_COMPOSE}" ]; then
    log_error "Connector admin compose file not found: ${CONNECTOR_ADMIN_COMPOSE}"
    exit 1
fi

if [ ! -f "${CONNECTOR_ADMIN_SNAPSHOT}" ]; then
    log_error "Connector admin snapshot override not found: ${CONNECTOR_ADMIN_SNAPSHOT}"
    exit 1
fi

# Main test execution
main() {
    log_info "Starting Connector Admin Snapshot Integration Tests"
    log_info "Testing snapshot: ${GITHUB_SHA}"
    log_info "Images:"
    log_info "  - ghcr.io/ai-pipestream/platform-registration-service:${GITHUB_SHA}"
    log_info "  - ghcr.io/ai-pipestream/connector-admin:${GITHUB_SHA}"
    
    # Ensure clean state
    cleanup
    
    # Start all services (infrastructure + platform-registration-service + connector-admin)
    log_info "Starting infrastructure and services..."
    GITHUB_SHA="${GITHUB_SHA}" docker compose \
        -f "${BASE_COMPOSE}" \
        -f "${PLATFORM_REG_COMPOSE}" \
        -f "${PLATFORM_REG_SNAPSHOT}" \
        -f "${CONNECTOR_ADMIN_COMPOSE}" \
        -f "${CONNECTOR_ADMIN_SNAPSHOT}" \
        --env-file <(echo "GITHUB_SHA=${GITHUB_SHA}") \
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
        -f "${PLATFORM_REG_COMPOSE}" -f "${PLATFORM_REG_SNAPSHOT}" \
        -f "${CONNECTOR_ADMIN_COMPOSE}" -f "${CONNECTOR_ADMIN_SNAPSHOT}" \
        --env-file <(echo "GITHUB_SHA=${GITHUB_SHA}") \
        ps
    
    log_info ""
    log_info "=== Snapshot Tests Passed! ==="
    log_info "Services are running:"
    log_info "  - platform-registration-service: http://localhost:38201 (gRPC: localhost:38201)"
    log_info "  - connector-admin: http://localhost:38107 (gRPC: localhost:38107)"
    log_info ""
    log_info "To test gRPC:"
    log_info "  grpcurl -plaintext localhost:38201 list"
    log_info "  grpcurl -plaintext localhost:38107 list"
    log_info ""
    log_info "To stop and clean up:"
    log_info "  docker compose -f ${BASE_COMPOSE} -f ${PLATFORM_REG_COMPOSE} -f ${PLATFORM_REG_SNAPSHOT} -f ${CONNECTOR_ADMIN_COMPOSE} -f ${CONNECTOR_ADMIN_SNAPSHOT} --env-file <(echo \"GITHUB_SHA=${GITHUB_SHA}\") down -v"
    log_info ""
    log_warn "Containers are still running. Run cleanup manually or use Ctrl+C to trigger cleanup."
}

# Handle script interruption
trap cleanup EXIT INT TERM

# Run main function
main "$@"
