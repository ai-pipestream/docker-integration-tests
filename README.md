# Docker Integration Tests

End-to-end integration tests for the various Docker deployments that make up the Pipestream AI Platform.

## Overview

This repository provides Docker Compose configurations and test scripts for deploying and validating the Pipestream AI Platform infrastructure services. All container images are sourced from Docker Hub (`docker.io`) with specific version tags (no SNAPSHOTS or `:latest` tags).

Based on the [DevServices baseline](https://github.com/ai-pipestream/platform-libraries/blob/main/devservices/devservices/src/main/resources/compose-devservices.yml) from the platform-libraries repository.

## Services

The following services are included in the deployment:

| Service | Image | Port(s) | Description |
|---------|-------|---------|-------------|
| Consul | `hashicorp/consul:1.20.1` | 8500, 8600 | Service discovery and configuration |
| MySQL | `mysql:8.0.40` | 3306 | Relational database |
| Kafka | `apache/kafka:3.9.0` | 9094 | Event streaming platform (KRaft mode) |
| Apicurio Registry | `apicurio/apicurio-registry:3.0.13` | 8081 | Schema registry |
| Apicurio Registry UI | `apicurio/apicurio-registry-ui:3.0.13` | 8888 | Schema registry web UI |
| OpenSearch | `opensearchproject/opensearch:3.1.0` | 9200, 9600 | Search and analytics engine |
| OpenSearch Dashboards | `opensearchproject/opensearch-dashboards:3.1.0` | 5601 | OpenSearch web UI |
| MinIO | `minio/minio:RELEASE.2024-11-07T00-52-20Z` | 9000, 9001 | S3-compatible object storage |
| Kafka UI | `provectuslabs/kafka-ui:v0.7.2` | 8889 | Kafka management web UI |
| Grafana LGTM | `grafana/otel-lgtm:0.11.9` | 3001, 5317, 5318 | Observability stack (Grafana + OTel + Prometheus + Tempo + Loki) |

## Prerequisites

- Docker Engine 24.0+
- Docker Compose v2.20+
- At least 8GB of available memory

## Quick Start

### Start All Services

```bash
docker compose up -d
```

### Stop All Services

```bash
docker compose down
```

### Stop and Remove Volumes

```bash
docker compose down -v
```

## Running Integration Tests

Execute the test script to validate all services:

```bash
./test-deployment.sh
```

This script will:
1. Start all services
2. Wait for health checks to pass
3. Validate service endpoints
4. Print a summary
5. Clean up containers

## Service Access

Once deployed, services are accessible at:

- **Consul UI**: http://localhost:8500
- **MySQL**: localhost:3306 (user: `pipeline`, password: `password`)
- **Kafka**: localhost:9094
- **Apicurio Registry API**: http://localhost:8081
- **Apicurio Registry UI**: http://localhost:8888
- **OpenSearch**: http://localhost:9200
- **OpenSearch Dashboards**: http://localhost:5601
- **MinIO Console**: http://localhost:9001 (user: `minioadmin`, password: `minioadmin`)
- **Kafka UI**: http://localhost:8889
- **Grafana**: http://localhost:3001

## Configuration

### MySQL Databases

The following databases are automatically created on startup:

- `pipeline` - Main application database
- `apicurio_registry` - Schema registry storage
- `pipeline_connector_dev` - Connector service database
- `pipeline_connector_intake_dev` - Intake connector database
- `pipeline_repo_dev` - Repository service database

### Network

All services are connected to the `pipeline-test-network` bridge network.

## Version Policy

All container images use specific version tags to ensure reproducible deployments:

- ❌ No `:latest` tags
- ❌ No SNAPSHOT versions
- ✅ Explicit semantic versions or release tags

## License

See [LICENSE](LICENSE) for details.
