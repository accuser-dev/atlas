# Prometheus Custom Image

This directory contains the Dockerfile for building a custom Prometheus image with pre-configured rules and settings.

## Base Image

- **Base**: `prom/prometheus:v3.7.3`
- **Official**: Yes, from the Prometheus project
- **Version**: Pinned to v3.7.3 for reproducibility and security (Dependabot tracks updates)
- **User**: Runs as non-root user (`nobody`) by default

## Building

```bash
# From the docker/prometheus directory
docker build -t atlas/prometheus:latest .

# Or from the project root using the Makefile
make build-prometheus
```

## Image Features

### Security

**Non-root User**
- Official Prometheus image runs as `nobody` user (non-root)
- Secure by default, no additional configuration needed
- Follows container security best practices

**Health Check**
- Built-in Docker/Incus health check using Prometheus's `/-/ready` endpoint
- Interval: 30 seconds
- Timeout: 3 seconds
- Start period: 15 seconds (Prometheus needs time to initialize)
- Retries: 3 attempts before marking unhealthy
- Enables automatic restart policies and monitoring integration

### Operations

**Working Directory**
- Set to `/prometheus` to match data storage location
- Consistent with Prometheus's default configuration

**OCI Labels**
- Standard Open Container Initiative metadata labels
- Enables better container registry integration
- Includes source repository, version, and description

## Customization Options

### 1. Default Configuration

Add a default `prometheus.yml`:

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'caddy'
    static_configs:
      - targets: ['caddy01.incus:2019']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana01.incus:3000']
```

### 2. Alert Rules

Create alert rules in `alerts/`:

```yaml
# alerts/alerts.yml
groups:
  - name: example
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} down"
```

### 3. Recording Rules

Create recording rules in `rules/`:

```yaml
# rules/rules.yml
groups:
  - name: example
    rules:
      - record: job:http_requests_total:rate5m
        expr: rate(http_requests_total[5m])
```

## Configuration in Terraform

The Terraform module supports injecting configuration at runtime:

```hcl
module "prometheus01" {
  source = "./modules/prometheus"

  prometheus_config = file("${path.module}/configs/prometheus.yml")
  # ... other configuration
}
```

Choose between:
- **Baked-in**: Copy config files in Dockerfile (faster startup, immutable)
- **Runtime**: Inject via Terraform (flexible, easier to modify)

## Usage

Prometheus is designed for internal use only (no public exposure). It will be accessed by:
- Grafana (for metrics visualization)
- Alertmanager (for alert routing)

## Production Deployment

Images are automatically built and published to `ghcr.io/accuser/atlas/prometheus:latest` by GitHub Actions when code is pushed to `main` or `develop` branches.

For local development:
```bash
# Build locally
make build-prometheus

# Test with Terraform
cd terraform
terraform plan
```

## Health Monitoring

The health check uses Prometheus's built-in `/-/ready` endpoint:

```bash
# Check Prometheus health directly
curl http://localhost:9090/-/ready

# Or via Incus
incus exec prometheus01 -- wget -qO- http://localhost:9090/-/ready
```

Expected response when healthy: `Prometheus Server is Ready.`
