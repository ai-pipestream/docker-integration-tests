# Platform Registration Service - Environment Variables Reference

This document details all environment variables required for running `platform-registration-service` in a Docker Compose environment with standard infrastructure services.

## Overview

The service connects to infrastructure services via Docker network service names (container-to-container communication). Standard ports are used throughout for consistency.

---

## Infrastructure Connection Variables

### Consul Service Discovery

| Variable | Default | Description |
|----------|---------|-------------|
| `CONSUL_HOST` | `consul` | Docker service name for Consul |
| `CONSUL_PORT` | `8500` | Consul HTTP API port |
| `PIPELINE_CONSUL_ENABLED` | `true` | Enable Consul integration |

**Docker Network**: `consul:8500` (internal)

---

### MySQL Database

| Variable | Default | Description |
|----------|---------|-------------|
| `QUARKUS_DATASOURCE_DB_KIND` | `mysql` | Database type |
| `QUARKUS_DATASOURCE_USERNAME` | `pipeline` | Database username |
| `QUARKUS_DATASOURCE_PASSWORD` | `password` | Database password |
| `QUARKUS_DATASOURCE_JDBC_URL` | `jdbc:mysql://mysql:3306/pipeline?...` | JDBC connection URL |
| `QUARKUS_DATASOURCE_REACTIVE_URL` | `mysql://mysql:3306/pipeline` | Reactive connection URL |

**Docker Network**: `mysql:3306` (internal)  
**Host Port**: `3306` (standard MySQL port)

**JDBC URL Parameters**:
- `useSSL=false` - No SSL for internal network
- `allowPublicKeyRetrieval=true` - Allow key retrieval
- `serverTimezone=UTC` - Timezone
- `autoReconnect=true` - Auto-reconnect on failure
- `connectTimeout=5000` - 5 second connection timeout
- `socketTimeout=10000` - 10 second socket timeout

---

### Kafka

| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka:9092` | Kafka bootstrap servers (internal) |
| `KAFKA_BOOTSTRAP_SERVERS_PLAINTEXT` | `kafka:9092` | Plaintext listener (internal) |

**Docker Network**: `kafka:9092` (internal PLAINTEXT listener)  
**Host Port**: `9094` (LOCALHOST listener for host access)

**Note**: Services in Docker network use `kafka:9092` (internal). Host access uses `localhost:9094`.

---

### Apicurio Registry

| Variable | Default | Description |
|----------|---------|-------------|
| `APICURIO_REGISTRY_URL` | `http://apicurio-registry:8080/apis/registry/v3` | Apicurio Registry API v3 URL |

**Docker Network**: `apicurio-registry:8080` (internal)  
**Host Port**: `8081` (mapped from container port 8080)

---

## HTTP and gRPC Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `QUARKUS_HTTP_HOST` | `0.0.0.0` | Bind HTTP to all interfaces |
| `QUARKUS_HTTP_PORT` | `38101` | HTTP port (shared with gRPC) |
| `QUARKUS_HTTP_ROOT_PATH` | `/platform-registration` | HTTP root path |
| `QUARKUS_GRPC_SERVER_USE_SEPARATE_SERVER` | `false` | gRPC uses same port as HTTP |
| `QUARKUS_GRPC_SERVER_ENABLE_REFLECTION_SERVICE` | `true` | Enable gRPC reflection (for grpcurl) |
| `QUARKUS_GRPC_SERVER_ENABLE_HEALTH_SERVICE` | `true` | Enable gRPC health service |

**Host Port**: `38101` (exposed for HTTP and gRPC)

**gRPC Testing**:
```bash
# List services via reflection
grpcurl -plaintext localhost:38101 list

# Call a service method
grpcurl -plaintext localhost:38101 <ServiceName>/<MethodName>
```

---

## Service Registration Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVICE_REGISTRATION_ENABLED` | `true` | Enable service self-registration |
| `SERVICE_REGISTRATION_SERVICE_NAME` | `platform-registration-service` | Service name for registration |
| `SERVICE_REGISTRATION_DESCRIPTION` | `Platform service registration...` | Service description |
| `SERVICE_REGISTRATION_SERVICE_TYPE` | `APPLICATION` | Service type |
| `PLATFORM_REGISTRATION_HOST` | `platform-registration-service` | Container hostname |
| `SERVICE_REGISTRATION_PORT` | `38101` | Service port |
| `SERVICE_REGISTRATION_CAPABILITIES` | `platform-registration,service-discovery` | Service capabilities |
| `SERVICE_REGISTRATION_TAGS` | `grpc,core-service,registration` | Service tags |

---

## Application Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `QUARKUS_APPLICATION_NAME` | `platform-registration-service` | Application name |
| `QUARKUS_LOG_LEVEL` | `INFO` | Root log level |
| `QUARKUS_LOG_CATEGORY_AI_PIPESTREAM_REGISTRY_LEVEL` | `INFO` | Registry package log level |

---

## Database Schema Management

| Variable | Default | Description |
|----------|---------|-------------|
| `QUARKUS_HIBERNATE_ORM_SCHEMA_MANAGEMENT_STRATEGY` | `none` | Let Flyway manage schema |
| `QUARKUS_FLYWAY_MIGRATE_AT_START` | `true` | Run Flyway migrations on startup |
| `QUARKUS_FLYWAY_REPAIR_AT_START` | `true` | Repair Flyway on startup |

---

## Metrics and Observability

| Variable | Default | Description |
|----------|---------|-------------|
| `QUARKUS_MICROMETER_EXPORT_PROMETHEUS_ENABLED` | `true` | Enable Prometheus metrics |

**Metrics Endpoint**: `http://localhost:38101/q/metrics`

---

## Standard Port Allocation

All services use standard ports for consistency:

| Service | Internal Port | Host Port | Purpose |
|---------|---------------|-----------|---------|
| **Consul** | 8500 | 8500 | HTTP API |
| **MySQL** | 3306 | 3306 | Database |
| **Kafka** | 9092 | (internal only) | PLAINTEXT listener |
| **Kafka** | 9094 | 9094 | LOCALHOST listener (host access) |
| **Apicurio Registry** | 8080 | 8081 | HTTP API |
| **Apicurio Registry UI** | 8080 | 8888 | Web UI |
| **OpenSearch** | 9200 | 9200 | HTTP API |
| **MinIO API** | 9000 | 9000 | S3 API |
| **MinIO Console** | 9001 | 9001 | Web Console |
| **Kafka UI** | 8080 | 8889 | Web UI |
| **Grafana** | 3000 | 3001 | Web UI |
| **Platform Registration** | 38101 | 38101 | HTTP + gRPC |

---

## Docker Network Service Discovery

All services communicate via Docker network service names:

- **Consul**: `consul:8500`
- **MySQL**: `mysql:3306`
- **Kafka**: `kafka:9092` (internal), `kafka:9094` (not used, host uses localhost:9094)
- **Apicurio Registry**: `apicurio-registry:8080`
- **OpenSearch**: `opensearch:9200`
- **MinIO**: `minio:9000`

**Network Name**: `pipeline-test-network` (bridge network)

---

## Usage Examples

### Snapshot Testing (GHCR)
```bash
cd docker-integration-tests/services/platform-registration-service

# Test with specific snapshot SHA
GITHUB_SHA=abc1234 docker compose \
  -f ../../docker-compose.yml \
  -f docker-compose.yml \
  -f docker-compose.snapshot.yml \
  up -d

# Verify health
curl http://localhost:38101/q/health/ready

# Test gRPC reflection
grpcurl -plaintext localhost:38101 list
```

### Release Testing (docker.io)
```bash
cd docker-integration-tests/services/platform-registration-service

# Test with specific version
VERSION=0.2.11 docker compose \
  -f ../../docker-compose.yml \
  -f docker-compose.yml \
  -f docker-compose.release.yml \
  up -d
```

### Running Service Tests
```bash
# After service is up
./test.sh
```

---

## Health Check Endpoints

- **Liveness**: `http://localhost:38101/q/health/live`
- **Readiness**: `http://localhost:38101/q/health/ready`
- **Startup**: `http://localhost:38101/q/health/started`
- **Metrics**: `http://localhost:38101/q/metrics`

---

## Troubleshooting

### Service Won't Start
1. Verify all infrastructure services are healthy: `docker compose ps`
2. Check service logs: `docker logs platform-registration-service`
3. Verify network connectivity: `docker exec platform-registration-service ping mysql`
4. Check environment variables: `docker exec platform-registration-service env | grep -E "(KAFKA|MYSQL|APICURIO)"`

### gRPC Reflection Not Working
1. Verify gRPC reflection is enabled: `QUARKUS_GRPC_SERVER_ENABLE_REFLECTION_SERVICE=true`
2. Check port is exposed: `docker port platform-registration-service`
3. Test from host: `grpcurl -plaintext localhost:38101 list`

### Database Connection Issues
1. Verify MySQL is healthy: `docker logs pipeline-mysql`
2. Test connection from service container: `docker exec platform-registration-service ping mysql`
3. Check JDBC URL format and parameters
4. Verify database exists: `docker exec pipeline-mysql mysql -u pipeline -ppassword -e "SHOW DATABASES;"`

### Kafka Connection Issues
1. Verify Kafka is healthy: `docker logs pipeline-kafka`
2. Test internal connection: `docker exec platform-registration-service nc -zv kafka 9092`
3. Verify `KAFKA_BOOTSTRAP_SERVERS=kafka:9092` (not `localhost:9094`)

