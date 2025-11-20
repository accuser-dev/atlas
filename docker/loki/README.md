# Loki Custom Image

This directory contains the Dockerfile for building a custom Loki image with pre-configured settings.

## Base Image

- **Base**: `grafana/loki:latest`
- **Official**: Yes, from Grafana Labs

## Building

```bash
# From the docker/loki directory
docker build -t atlas/loki:latest .

# Or from the project root using the Makefile
make build-loki
```

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
