#!/usr/bin/env bash
#
# Service-specific validation tests for platform-registration-service
# This script validates that the service is working correctly in the container

set -e

SERVICE_NAME="platform-registration-service"
SERVICE_PORT=${SERVICE_PORT:-38201}
SERVICE_URL="http://localhost:${SERVICE_PORT}/platform-registration"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Wait for service to be ready
wait_for_service() {
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for ${SERVICE_NAME} to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf --max-time 5 "${SERVICE_URL}/q/health/ready" > /dev/null 2>&1; then
            log_info "${SERVICE_NAME} is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "${SERVICE_NAME} did not become ready within ${max_attempts} attempts"
    return 1
}

# Test health endpoints
test_health() {
    log_info "Testing health endpoints..."
    
    # Test liveness
    if curl -sf --max-time 10 "${SERVICE_URL}/q/health/live" > /dev/null; then
        log_info "✓ Liveness check passed"
    else
        log_error "✗ Liveness check failed"
        return 1
    fi
    
    # Test readiness
    if curl -sf --max-time 10 "${SERVICE_URL}/q/health/ready" > /dev/null; then
        log_info "✓ Readiness check passed"
    else
        log_error "✗ Readiness check failed"
        return 1
    fi
    
    # Test startup
    if curl -sf --max-time 10 "${SERVICE_URL}/q/health/started" > /dev/null; then
        log_info "✓ Startup check passed"
    else
        log_warn "⚠ Startup check failed (may be normal if service is fully started)"
    fi
    
    return 0
}

# Test gRPC reflection (if grpcurl is available)
test_grpc_reflection() {
    if ! command -v grpcurl &> /dev/null; then
        log_warn "grpcurl not found, skipping gRPC reflection test"
        log_warn "Install grpcurl: https://github.com/fullstorydev/grpcurl"
        return 0
    fi
    
    log_info "Testing gRPC reflection..."
    
    # List services via reflection
    if grpcurl -plaintext localhost:${SERVICE_PORT} list > /dev/null 2>&1; then
        log_info "✓ gRPC reflection is working"
        
        # List available services
        log_info "Available gRPC services:"
        grpcurl -plaintext localhost:${SERVICE_PORT} list | sed 's/^/  - /'
        return 0
    else
        log_error "✗ gRPC reflection test failed"
        return 1
    fi
}

# Test metrics endpoint
test_metrics() {
    log_info "Testing metrics endpoint..."
    
    if curl -sf --max-time 10 "${SERVICE_URL}/q/metrics" > /dev/null; then
        log_info "✓ Metrics endpoint is accessible"
        return 0
    else
        log_warn "⚠ Metrics endpoint not accessible (may not be configured)"
        return 0
    fi
}

# Main test execution
main() {
    log_info "Starting ${SERVICE_NAME} validation tests"
    
    if ! wait_for_service; then
        log_error "Service is not ready, cannot run tests"
        exit 1
    fi
    
    local failed=0
    
    if ! test_health; then
        failed=1
    fi
    
    if ! test_grpc_reflection; then
        failed=1
    fi
    
    if ! test_metrics; then
        # Metrics failure is not critical
        :
    fi
    
    echo ""
    if [ $failed -eq 0 ]; then
        log_info "=== All tests passed! ==="
        exit 0
    else
        log_error "=== Some tests failed ==="
        exit 1
    fi
}

main "$@"

