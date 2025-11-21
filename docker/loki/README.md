# Loki Custom Image

This directory contains the Dockerfile for building a custom Loki image with pre-configured settings.

## Base Image

- **Base**: `grafana/loki:3.6.0`
- **Official**: Yes, from Grafana Labs
- **Version**: Pinned to 3.6.0 for reproducibility and security (Dependabot tracks updates)
- **User**: Runs as non-root user (UID 10001) by default

## Building

```bash
# From the docker/loki directory
docker build -t atlas/loki:latest .

# Or from the project root using the Makefile
make build-loki
```

## Image Features

### Security

**Non-root User**
- Official Loki image runs as UID 10001 (non-root)
- Secure by default, no additional configuration needed
- Follows container security best practices

**Health Check**
- Built-in Docker/Incus health check using Loki's `/ready` endpoint
- Interval: 30 seconds
- Timeout: 3 seconds
- Start period: 15 seconds (Loki needs time to initialize)
- Retries: 3 attempts before marking unhealthy
- Enables automatic restart policies and monitoring integration

### Operations

**Working Directory**
- Set to `/loki` to match data storage location
- Consistent with Loki's default configuration

**OCI Labels**
- Standard Open Container Initiative metadata labels
- Enables better container registry integration
- Includes source repository, version, and description

## Customization Options

### Default Configuration

Add a custom `loki-config.yaml`:

```yaml
# loki-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /loki/index

  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
```

## Configuration in Terraform

The Terraform module will handle most configuration. Use this Dockerfile primarily for:
- Adding custom plugins or extensions
- Baking in organization-specific defaults
- Creating a versioned, reproducible base image

## Usage

Loki is designed for internal use only (no public exposure). It will be accessed by:
- Grafana (for log visualization)
- Log shippers (Promtail, Fluentd, etc.)

## Production Deployment

Images are automatically built and published to `ghcr.io/accuser/atlas/loki:latest` by GitHub Actions when code is pushed to `main` or `develop` branches.

For local development:
```bash
# Build locally
make build-loki

# Test with Terraform
cd terraform
terraform plan
```

## Health Monitoring

The health check uses Loki's built-in `/ready` endpoint:

```bash
# Check Loki health directly
curl http://localhost:3100/ready

# Or via Incus
incus exec loki01 -- wget -qO- http://localhost:3100/ready
```

Expected response when healthy: `ready`
