# Platform Registration Service - Integration Test Guide

## Overview

This directory contains comprehensive integration tests for the `platform-registration-service`. The tests verify that the service:

1. ✅ Starts up correctly
2. ✅ Health endpoints are working
3. ✅ gRPC reflection is enabled
4. ✅ Can make actual gRPC calls (register, listServices, getService, etc.)
5. ✅ Integrates with infrastructure services (Consul, MySQL, Kafka, Apicurio)

## Prerequisites

1. **Docker and Docker Compose** - Required for running infrastructure and service containers
2. **grpcurl** - Required for gRPC testing
   ```bash
   # macOS
   brew install grpcurl
   
   # Linux
   # See: https://github.com/fullstorydev/grpcurl#installation
   ```

## Running Tests

### Option 1: Using Test Scripts (Recommended)

#### Test Snapshot Images (GHCR)

```bash
# From docker-integration-tests root
./test-snapshot.sh [GITHUB_SHA]

# Examples:
./test-snapshot.sh                    # Latest snapshot
./test-snapshot.sh abc1234            # Specific SHA
./test-snapshot.sh main-abc1234       # Branch-specific snapshot
```

#### Test Release Images (docker.io)

```bash
# From docker-integration-tests root
./test-release.sh [VERSION]

# Examples:
./test-release.sh                    # Latest release
./test-release.sh 0.2.11             # Specific version
```

### Option 2: Manual Testing

1. **Start Infrastructure Services**

```bash
# From docker-integration-tests root
docker compose up -d
```

2. **Start Platform Registration Service**

```bash
# For snapshot (GHCR)
GITHUB_SHA=abc1234 docker compose \
  -f docker-compose.yml \
  -f services/platform-registration-service/docker-compose.yml \
  -f services/platform-registration-service/docker-compose.snapshot.yml \
  up -d

# For release (docker.io)
VERSION=0.2.11 docker compose \
  -f docker-compose.yml \
  -f services/platform-registration-service/docker-compose.yml \
  -f services/platform-registration-service/docker-compose.release.yml \
  up -d
```

3. **Run Service-Specific Tests**

```bash
cd services/platform-registration-service
./test.sh
```

## Test Coverage

### Health Endpoints
- ✅ Liveness (`/q/health/live`)
- ✅ Readiness (`/q/health/ready`)
- ✅ Startup (`/q/health/started`)
- ✅ Full health (`/q/health`)

### gRPC Reflection
- ✅ List available services
- ✅ List methods for `PlatformRegistrationService`

### gRPC Method Calls
- ✅ `ListServices` - List all registered services
- ✅ `ListModules` - List all registered modules
- ✅ `GetService` - Get service by name
- ✅ `Register` - Register a test service
- ✅ `Unregister` - Unregister the test service

### Infrastructure Integration
- ✅ **Consul** - Verify service is registered in Consul
- ✅ **MySQL** - Verify database connectivity (via health check)
- ✅ **Kafka** - Verify Kafka integration (via service readiness)
- ✅ **Apicurio Registry** - Verify Apicurio is accessible

### Metrics
- ✅ Metrics endpoint (`/q/metrics`)
- ✅ JVM metrics available

## Test Output

The test script provides color-coded output:

- 🟢 **GREEN [INFO]** - Successful operations
- 🔵 **BLUE [TEST]** - Test section headers
- 🟡 **YELLOW [WARN]** - Non-critical warnings
- 🔴 **RED [ERROR]** - Test failures

## Expected Results

When all tests pass, you should see:

```
==========================================
=== All Integration Tests Passed! ===

Service is fully operational and integrated with:
  ✓ Consul (service discovery)
  ✓ MySQL (database)
  ✓ Kafka (event streaming)
  ✓ Apicurio Registry (schema registry)
```

## Troubleshooting

### Service Not Starting

1. Check service logs:
   ```bash
   docker logs platform-registration-service --tail 100
   ```

2. Verify infrastructure services are healthy:
   ```bash
   docker compose ps
   ```

3. Check network connectivity:
   ```bash
   docker network inspect pipeline-integration-network
   ```

### gRPC Tests Failing

1. Verify grpcurl is installed:
   ```bash
   grpcurl --version
   ```

2. Test gRPC reflection manually:
   ```bash
   grpcurl -plaintext localhost:38201 list
   ```

3. Check service logs for gRPC errors

### Infrastructure Integration Failures

1. **Consul**: Verify Consul is accessible
   ```bash
   curl http://localhost:8500/v1/agent/services
   ```

2. **MySQL**: Check MySQL connectivity
   ```bash
   docker exec -it it-mysql mysql -u pipeline -ppassword -e "SHOW DATABASES;"
   ```

3. **Kafka**: Verify Kafka is running
   ```bash
   docker exec -it it-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
   ```

4. **Apicurio**: Check Apicurio health
   ```bash
   curl http://localhost:8081/health
   ```

## Next Steps

Once platform-registration-service tests pass:

1. ✅ Verify all infrastructure services are working
2. ✅ Verify gRPC calls succeed
3. ✅ Verify service appears in Consul
4. ✅ Move on to testing `account-service` integration
5. ✅ Then test `connector-admin` integration

## Service Endpoints

Once running, the service is accessible at:

- **HTTP**: http://localhost:38201/platform-registration
- **gRPC**: localhost:38201
- **Health**: http://localhost:38201/platform-registration/q/health
- **Metrics**: http://localhost:38201/platform-registration/q/metrics

## Example gRPC Calls

### List Services
```bash
grpcurl -plaintext -d '{}' localhost:38201 \
  ai.pipestream.platform.registration.v1.PlatformRegistrationService/ListServices
```

### Register a Service
```bash
grpcurl -plaintext -d '{
  "name": "test-service",
  "type": "SERVICE_TYPE_SERVICE",
  "connectivity": {
    "advertised_host": "localhost",
    "advertised_port": 9999
  },
  "version": "1.0.0",
  "tags": ["test"],
  "capabilities": ["test"]
}' localhost:38201 \
  ai.pipestream.platform.registration.v1.PlatformRegistrationService/Register
```

### Get Service
```bash
grpcurl -plaintext -d '{"service_name": "platform-registration-service"}' \
  localhost:38201 \
  ai.pipestream.platform.registration.v1.PlatformRegistrationService/GetService
```
