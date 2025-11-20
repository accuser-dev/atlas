# Grafana Custom Image

This directory contains the Dockerfile for building a custom Grafana image with pre-installed plugins and configuration.

## Base Image

- **Base**: `grafana/grafana:latest`
- **Official**: Yes, from Grafana Labs

## Building

```bash
# From the docker/grafana directory
docker build -t atlas/grafana:latest .

# Or from the project root using the Makefile
make build-grafana
```

## Customization Options

### 1. Install Plugins

Uncomment plugin installation lines in the Dockerfile:

```dockerfile
RUN grafana-cli plugins install grafana-piechart-panel
RUN grafana-cli plugins install grafana-worldmap-panel
```

### 2. Add Provisioning

Create a `provisioning/` directory with:
- `datasources/` - Pre-configured data sources (Prometheus, Loki)
- `dashboards/` - Pre-loaded dashboards
- `notifiers/` - Alert notification channels

Example structure:
```
provisioning/
├── datasources/
│   └── prometheus.yml
├── dashboards/
│   ├── dashboard-provider.yml
│   └── my-dashboard.json
└── notifiers/
    └── slack.yml
```

### 3. Custom Configuration

Copy a custom `grafana.ini` with your settings:

```dockerfile
COPY grafana.ini /etc/grafana/grafana.ini
```

## Usage in Terraform

Reference this image in your Terraform configuration:

```hcl
module "grafana01" {
  source = "./modules/grafana"

  image = "docker:atlas/grafana:latest"
  # ... other configuration
}
```
