# Loki Custom Image

This directory contains the Dockerfile for building a custom Loki image with TLS support via step-ca.

## Base Image

- **Base**: `grafana/loki:3.6.1` (binary extracted)
- **Runtime**: `alpine:3.22` (for shell and TLS support)
- **Official**: Yes, Loki binary from Grafana Labs
- **Version**: Pinned to 3.6.1 for reproducibility and security (Dependabot tracks updates)
- **User**: Runs as non-root user (UID 10001) by default

**Note**: The official Loki image is scratch-based (no shell). This custom image uses Alpine as the base to enable TLS certificate management while preserving the official Loki binary.

## Building

```bash
# From the docker/loki directory
docker build -t atlas/loki:latest .

# Or from the project root using the Makefile
make build-loki
```

## Image Features

### TLS Support

This image includes built-in TLS support via step-ca integration:

- **step CLI**: Pre-installed for certificate requests
- **ACME Protocol**: Automatic certificate provisioning
- **Backward Compatible**: TLS is opt-in (disabled by default)

**Enable TLS with environment variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_TLS` | Enable TLS mode | `false` |
| `STEPCA_URL` | step-ca server URL | (required if TLS enabled) |
| `STEPCA_FINGERPRINT` | CA root certificate fingerprint | (required if TLS enabled) |
| `CERT_DURATION` | Certificate validity duration | `24h` |
| `CERT_RENEW_BEFORE` | Renew certificate before expiry | `1h` |

**Example Terraform configuration with TLS:**

```hcl
module "loki01" {
  source = "./modules/loki"

  environment_variables = {
    ENABLE_TLS         = "true"
    STEPCA_URL         = "https://step-ca01.incus:9000"
    STEPCA_FINGERPRINT = "abc123..."
  }
}
```

### Security

**Non-root User**
- Runs as UID 10001 (loki user), matching official image
- Secure by default, no additional configuration needed
- Follows container security best practices

**Health Check**
- Built-in Docker/Incus health check using Loki's `/ready` endpoint
- Automatically adapts to HTTP or HTTPS based on TLS mode
- Interval: 30 seconds
- Timeout: 3 seconds
- Start period: 30 seconds (extended for TLS certificate acquisition)
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

The image includes a default `loki-config.yaml` suitable for single-instance deployments. To customize:

```yaml
# loki-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
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

Images are automatically built and published to `ghcr.io/accuser-dev/atlas/loki:latest` by GitHub Actions when code is pushed to the `main` branch.

For local development:
```bash
# Build locally
make build-loki

# Test with OpenTofu
cd terraform
tofu plan
```

## Health Monitoring

The health check uses Loki's built-in `/ready` endpoint:

```bash
# Check Loki health directly (HTTP mode)
curl http://localhost:3100/ready

# Check Loki health (HTTPS mode)
curl -k https://localhost:3100/ready

# Or via Incus
incus exec loki01 -- wget -qO- http://localhost:3100/ready
```

Expected response when healthy: `ready`
