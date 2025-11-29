#!/usr/bin/env bash
#
# Test SNAPSHOT images from GHCR (for local development)
# 
# Usage:
#   ./test-snapshot.sh [GITHUB_SHA]
#   
# Examples:
#   ./test-snapshot.sh                    # Uses latest snapshot
#   ./test-snapshot.sh abc1234            # Test specific snapshot by SHA
#   ./test-snapshot.sh main-abc1234       # Test branch-specific snapshot

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_COMPOSE="${SCRIPT_DIR}/docker-compose.yml"
SERVICE_DIR="${SCRIPT_DIR}/services/platform-registration-service"
SERVICE_COMPOSE="${SERVICE_DIR}/docker-compose.yml"
SNAPSHOT_OVERRIDE="${SERVICE_DIR}/docker-compose.snapshot.yml"

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
    docker compose -f "${BASE_COMPOSE}" -f "${SERVICE_COMPOSE}" -f "${SNAPSHOT_OVERRIDE}" \
        --env-file <(echo "GITHUB_SHA=${GITHUB_SHA}") \
        down -v --remove-orphans 2>/dev/null || true
}

# Validate compose files exist
if [ ! -f "${BASE_COMPOSE}" ]; then
    log_error "Base compose file not found: ${BASE_COMPOSE}"
    exit 1
fi

if [ ! -f "${SERVICE_COMPOSE}" ]; then
    log_error "Service compose file not found: ${SERVICE_COMPOSE}"
    exit 1
fi

if [ ! -f "${SNAPSHOT_OVERRIDE}" ]; then
    log_error "Snapshot override file not found: ${SNAPSHOT_OVERRIDE}"
    exit 1
fi

# Main test execution
main() {
    log_info "Starting Snapshot Integration Tests"
    log_info "Testing snapshot: ${GITHUB_SHA}"
    log_info "Image: ghcr.io/ai-pipestream/platform-registration-service:${GITHUB_SHA}"
    
    # Ensure clean state
    cleanup
    
    # Start all services (infrastructure + platform-registration-service)
    log_info "Starting infrastructure and service..."
    GITHUB_SHA="${GITHUB_SHA}" docker compose \
        -f "${BASE_COMPOSE}" \
        -f "${SERVICE_COMPOSE}" \
        -f "${SNAPSHOT_OVERRIDE}" \
        --env-file <(echo "GITHUB_SHA=${GITHUB_SHA}") \
        up -d
    
    # Wait for infrastructure services
    log_info "Waiting for infrastructure services to be healthy..."
    sleep 10
    
    # Wait for service to be ready
    log_test "Waiting for platform-registration-service to be ready..."
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf --max-time 5 "http://localhost:38101/q/health/ready" > /dev/null 2>&1; then
            log_info "Service is ready!"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Service did not become ready within ${max_attempts} attempts"
            docker logs platform-registration-service --tail 50
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
        log_test "Running service-specific tests..."
        cd "${SERVICE_DIR}"
        if ./test.sh; then
            log_info "Service-specific tests passed!"
        else
            log_error "Service-specific tests failed!"
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
    docker compose -f "${BASE_COMPOSE}" -f "${SERVICE_COMPOSE}" -f "${SNAPSHOT_OVERRIDE}" \
        --env-file <(echo "GITHUB_SHA=${GITHUB_SHA}") \
        ps
    
    log_info ""
    log_info "=== Snapshot Tests Passed! ==="
    log_info "Service is running at: http://localhost:38101"
    log_info "gRPC endpoint: localhost:38101"
    log_info ""
    log_info "To test gRPC:"
    log_info "  grpcurl -plaintext localhost:38101 list"
    log_info ""
    log_info "To stop and clean up:"
    log_info "  docker compose -f ${BASE_COMPOSE} -f ${SERVICE_COMPOSE} -f ${SNAPSHOT_OVERRIDE} --env-file <(echo \"GITHUB_SHA=${GITHUB_SHA}\") down -v"
    log_info ""
    log_warn "Containers are still running. Run cleanup manually or use Ctrl+C to trigger cleanup."
}

# Handle script interruption
trap cleanup EXIT INT TERM

# Run main function
main "$@"

