# Grafana Custom Image

This directory contains the Dockerfile for building a custom Grafana image with pre-installed plugins and configuration.

## Base Image

- **Base**: `grafana/grafana:12.3.0`
- **Official**: Yes, from Grafana Labs
- **Version**: Pinned to 12.3.0 for reproducibility and security (Dependabot tracks updates)
- **User**: Runs as `grafana` user (non-root) at runtime

## Building

```bash
# From the docker/grafana directory
docker build -t atlas/grafana:latest .

# Or from the project root using the Makefile
make build-grafana
```

## Image Features

### Security

**Non-root User**
- Runs as `grafana` user at runtime (not root)
- Temporarily switches to root only for plugin installation during build
- Follows container security best practices

**Health Check**
- Built-in Docker/Incus health check using Grafana's `/api/health` endpoint
- Interval: 30 seconds
- Timeout: 3 seconds
- Start period: 30 seconds (Grafana needs time to initialize, especially with plugins)
- Retries: 3 attempts before marking unhealthy
- Enables automatic restart policies and monitoring integration

### Operations

**Working Directory**
- Set to `/usr/share/grafana` (Grafana's installation directory)
- Consistent with Grafana's default configuration

**OCI Labels**
- Standard Open Container Initiative metadata labels
- Enables better container registry integration
- Includes source repository, version, and description

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

## Production Deployment

Images are automatically built and published to `ghcr.io/accuser/atlas/grafana:latest` by GitHub Actions when code is pushed to `main` or `develop` branches.

For local development:
```bash
# Build locally
make build-grafana

# Test with Terraform
cd terraform
terraform plan
```

## Health Monitoring

The health check uses Grafana's built-in `/api/health` endpoint:

```bash
# Check Grafana health directly
curl http://localhost:3000/api/health

# Or via Incus
incus exec grafana01 -- wget -qO- http://localhost:3000/api/health
```

Expected response when healthy:
```json
{"commit":"...","database":"ok","version":"12.3.0"}
```
