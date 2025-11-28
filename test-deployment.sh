#!/usr/bin/env bash
#
# Integration test script for verifying docker-compose deployment
# This script starts all services and validates that they are healthy
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
TIMEOUT=300  # 5 minutes timeout for all services to become healthy

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

cleanup() {
    log_info "Cleaning up containers..."
    docker compose -f "${COMPOSE_FILE}" down -v --remove-orphans 2>/dev/null || true
}

wait_for_healthy() {
    local service=$1
    local container=$2
    local elapsed=0
    local interval=5

    log_info "Waiting for ${service} to become healthy..."
    
    while [ $elapsed -lt $TIMEOUT ]; do
        local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not_found")
        
        if [ "$status" = "healthy" ]; then
            log_info "${service} is healthy!"
            return 0
        elif [ "$status" = "unhealthy" ]; then
            log_error "${service} is unhealthy!"
            docker logs "$container" --tail 50
            return 1
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_error "${service} did not become healthy within ${TIMEOUT} seconds"
    docker logs "$container" --tail 50
    return 1
}

# Main test execution
main() {
    log_info "Starting Docker Integration Tests"
    log_info "Using compose file: ${COMPOSE_FILE}"
    
    # Ensure clean state
    cleanup
    
    # Start all services
    log_info "Starting all services..."
    docker compose -f "${COMPOSE_FILE}" up -d
    
    # Wait for services with health checks
    local services_with_healthcheck=(
        "consul:pipeline-consul"
        "mysql:pipeline-mysql"
        "kafka:pipeline-kafka"
        "apicurio-registry:pipeline-apicurio-registry"
        "opensearch:pipeline-opensearch"
        "minio:pipeline-minio"
    )
    
    local failed=0
    for service_container in "${services_with_healthcheck[@]}"; do
        IFS=':' read -r service container <<< "$service_container"
        if ! wait_for_healthy "$service" "$container"; then
            failed=1
        fi
    done
    
    # Validate service endpoints
    log_info "Validating service endpoints..."
    
    # Test Consul
    if curl -sf --max-time 10 http://localhost:8500/v1/status/leader > /dev/null; then
        log_info "Consul API is responding"
    else
        log_error "Consul API is not responding"
        failed=1
    fi
    
    # Test OpenSearch
    if curl -sf --max-time 10 http://localhost:9200/_cluster/health > /dev/null; then
        log_info "OpenSearch API is responding"
    else
        log_error "OpenSearch API is not responding"
        failed=1
    fi
    
    # Test MinIO
    if curl -sf --max-time 10 http://localhost:9000/minio/health/live > /dev/null; then
        log_info "MinIO API is responding"
    else
        log_error "MinIO API is not responding"
        failed=1
    fi
    
    # Test Apicurio Registry
    if curl -sf --max-time 10 http://localhost:8081/health > /dev/null || curl -sf --max-time 10 http://localhost:8081/q/health > /dev/null; then
        log_info "Apicurio Registry API is responding"
    else
        log_error "Apicurio Registry API is not responding"
        failed=1
    fi
    
    # Test Grafana LGTM
    if curl -sf --max-time 10 http://localhost:3001/api/health > /dev/null; then
        log_info "Grafana LGTM is responding"
    else
        log_warn "Grafana LGTM may still be starting up"
    fi
    
    # Print summary
    echo ""
    log_info "=== Test Summary ==="
    docker compose -f "${COMPOSE_FILE}" ps
    
    if [ $failed -eq 0 ]; then
        log_info "All integration tests passed!"
        cleanup
        exit 0
    else
        log_error "Some integration tests failed!"
        cleanup
        exit 1
    fi
}

# Handle script interruption
trap cleanup EXIT

# Run main function
main "$@"
