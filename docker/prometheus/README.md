# Prometheus Custom Image

This directory contains the Dockerfile for building a custom Prometheus image with pre-configured rules and settings.

## Base Image

- **Base**: `prom/prometheus:latest`
- **Official**: Yes, from the Prometheus project

## Building

```bash
# From the docker/prometheus directory
docker build -t atlas/prometheus:latest .

# Or from the project root using the Makefile
make build-prometheus
```

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
