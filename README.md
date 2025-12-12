# Atlas Infrastructure

An OpenTofu-based infrastructure project for managing Incus containers running a complete observability and monitoring stack.

## Overview

This project provides a declarative infrastructure setup for:
- **Caddy** - Reverse proxy with automatic HTTPS
- **Grafana** - Visualization and dashboarding
- **Prometheus** - Metrics collection and storage
- **Loki** - Log aggregation
- **Alertmanager** - Alert routing and notifications
- **step-ca** - Internal PKI for service TLS certificates
- **Node Exporter** - Host-level system metrics
- **Mosquitto** - MQTT broker for IoT messaging
- **Cloudflared** - Cloudflare Tunnel for Zero Trust access
- **Atlantis** - GitOps controller for PR-based infrastructure management (optional)

All services run in Incus containers with persistent storage, network isolation, and automatic configuration management.

## Project Structure

```
atlas/
├── docker/                    # Custom Docker images
│   ├── alertmanager/         # Alert routing and notifications
│   ├── atlantis/             # GitOps controller
│   ├── caddy/                # Reverse proxy with Cloudflare DNS plugin
│   ├── cloudflared/          # Cloudflare Tunnel client
│   ├── grafana/              # Grafana with optional plugins
│   ├── loki/                 # Log aggregation
│   ├── mosquitto/            # MQTT broker
│   ├── prometheus/           # Metrics collection with optional rules
│   └── step-ca/              # Internal PKI certificate authority
│
├── terraform/                 # Infrastructure as Code (OpenTofu)
│   ├── bootstrap/            # Bootstrap project for remote state
│   ├── modules/              # Reusable service modules
│   │   ├── alertmanager/
│   │   ├── atlantis/         # GitOps controller (optional)
│   │   ├── base-infrastructure/  # Networks and base profiles
│   │   ├── caddy/
│   │   ├── caddy-gitops/     # Dedicated Caddy for GitOps (optional)
│   │   ├── cloudflared/
│   │   ├── grafana/
│   │   ├── incus-loki/       # Native Incus logging to Loki
│   │   ├── incus-metrics/    # Incus container metrics
│   │   ├── loki/
│   │   ├── mosquitto/
│   │   ├── node-exporter/
│   │   ├── prometheus/
│   │   └── step-ca/
│   ├── main.tf               # Service instantiations
│   ├── locals.tf             # Centralized service configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output values
│   └── terraform.tfvars      # Secrets (gitignored)
│
├── .github/workflows/        # CI/CD workflows
│   ├── ci.yml                # Validation and testing
│   └── release.yml           # Build and publish images
├── atlantis.yaml             # Atlantis repository configuration
├── Makefile                  # Build and deployment automation
├── CLAUDE.md                 # Detailed architecture documentation
├── CONTRIBUTING.md           # Contribution guidelines
├── BACKUP.md                 # Backup and disaster recovery
├── GITOPS.md                 # GitOps workflow with Atlantis
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- [Incus](https://linuxcontainers.org/incus/) installed and running
- [OpenTofu](https://opentofu.org/) >= 1.6 (or Terraform >= 1.6)
- Cloudflare API token (for DNS-01 ACME challenges)
- GitHub account (images published to ghcr.io)

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/accuser-dev/atlas.git
   cd atlas
   ```

2. **Bootstrap remote state** (first time only):
   ```bash
   make bootstrap
   ```

3. **Create terraform.tfvars**:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit with your values:
   # - cloudflare_api_token
   # - network addresses (IPv4)
   ```

4. **Deploy infrastructure**:
   ```bash
   make init
   make plan
   make apply
   ```

   Or use the combined command:
   ```bash
   make deploy
   ```

5. **View outputs**:
   ```bash
   cd terraform
   tofu output
   ```

## Docker Images

### Production Images (GitHub Container Registry)

All services use custom images automatically built and published by GitHub Actions:

- **Alertmanager**: `ghcr.io/accuser-dev/atlas/alertmanager:latest`
- **Caddy**: `ghcr.io/accuser-dev/atlas/caddy:latest`
- **Cloudflared**: `ghcr.io/accuser-dev/atlas/cloudflared:latest`
- **Grafana**: `ghcr.io/accuser-dev/atlas/grafana:latest`
- **Loki**: `ghcr.io/accuser-dev/atlas/loki:latest`
- **Mosquitto**: `ghcr.io/accuser-dev/atlas/mosquitto:latest`
- **Prometheus**: `ghcr.io/accuser-dev/atlas/prometheus:latest`
- **step-ca**: `ghcr.io/accuser-dev/atlas/step-ca:latest`

Images are:
- Built on every push to `main`
- Published to GitHub Container Registry (ghcr.io)
- Publicly accessible (no authentication required)
- Extended from official images with custom plugins and configuration

### Local Development

Build images locally for testing:
```bash
make build-all           # Build all images
make build-grafana       # Build specific service
```

**Note:** Local builds are for testing only. Production deployments use images from ghcr.io.

## Usage

### Managing Infrastructure

Initialize OpenTofu:
```bash
make init
```

Plan changes:
```bash
make plan
```

Apply changes:
```bash
make apply
```

Destroy infrastructure:
```bash
make destroy
```

### Full Deployment

Deploy infrastructure (pulls images from ghcr.io):
```bash
make deploy
```

## Configuration

### Using Custom vs Official Images

**Default: Custom Images from ghcr.io**

All modules default to custom images from GitHub Container Registry.

**Switching to Official Images:**

Override the `image` variable in `terraform/main.tf`:

```hcl
module "grafana01" {
  source = "./modules/grafana"

  # Use official image instead of custom
  image = "docker:grafana/grafana:latest"

  # ... other configuration
}
```

### Customizing Docker Images

1. Edit the Dockerfile in `docker/<service>/Dockerfile`
2. Add plugins, configuration, or customizations
3. Test locally: `make build-<service>`
4. Push to GitHub (merge PR to main)
5. GitHub Actions builds and publishes to ghcr.io
6. Run `make apply` to pull new image

### Network Configuration

Two networks are defined (gitops is optional):
- **production** (10.10.0.0/24) - For public-facing services (Mosquitto)
- **management** (10.20.0.0/24) - For internal services (monitoring stack, PKI)
- **gitops** (10.30.0.0/24) - For GitOps automation (optional, enabled with `enable_gitops`)

Configure IP addresses in `terraform/terraform.tfvars`.

### Adding New Services

See [CLAUDE.md](CLAUDE.md#adding-new-service-modules) for detailed instructions on adding new services.

## Architecture

### Key Features

- **Declarative Infrastructure** - Everything defined in OpenTofu
- **Modular Design** - Reusable service modules
- **CI/CD Integration** - Automated image builds via GitHub Actions
- **Custom Images** - Published to GitHub Container Registry
- **Persistent Storage** - Data survives container restarts with optional automated snapshots
- **Automatic HTTPS** - Let's Encrypt via Cloudflare DNS
- **Network Isolation** - Separate networks for different environments
- **Dynamic Configuration** - Auto-generated reverse proxy configs
- **Native Incus Integration** - Container metrics and logging via Incus API

### Service Architecture

```
Internet
    │
    ├──[Cloudflared]──── Cloudflare Tunnel (Zero Trust)
    │
    ↓
[Caddy Reverse Proxy] ← HTTPS certificates via Cloudflare DNS
    │
    ├──[Grafana] ─────→ Visualization
    │       │
    │       ├─────────→ [Prometheus] → Metrics storage
    │       │               ↑
    │       │           [Node Exporter] → Host metrics
    │       │           [Incus Metrics] → Container metrics
    │       │
    │       └─────────→ [Loki] → Log aggregation
    │                       ↑
    │                   [Incus Loki] → Container logs
    │
    └──[Mosquitto] ───→ MQTT (ports 1883/8883)

[Prometheus] → [Alertmanager] → Notifications

[step-ca] → Internal TLS certificates for all services
```

**Public Services** (via Caddy):
- Grafana: `https://grafana.yourdomain.com`

**External TCP Services** (via Incus proxy):
- Mosquitto MQTT: Host ports 1883 (MQTT), 8883 (MQTTS)

**Internal Services** (Incus network only):
- Prometheus: `http://prometheus01.incus:9090`
- Loki: `http://loki01.incus:3100`
- Alertmanager: `http://alertmanager01.incus:9093`
- step-ca: `https://step-ca01.incus:9000` (ACME server)
- Node Exporter: `http://node-exporter01.incus:9100`

### Storage Volumes

Persistent storage for each service:
- `grafana01-data` (10GB) - Dashboards and settings
- `loki01-data` (50GB) - Log storage
- `prometheus01-data` (100GB) - Metrics storage
- `alertmanager01-data` (1GB) - Silences and state
- `step-ca01-data` (1GB) - CA keys and database
- `mosquitto01-data` (5GB) - MQTT retained messages

All volumes support optional automated snapshot scheduling via Terraform variables. See [BACKUP.md](BACKUP.md) for details.

## CI/CD

The project uses separate workflows for validation and releases:

### CI Workflow (`ci.yml`)

**Triggers:** Pull requests and pushes to feature branches

**What it does:**
1. OpenTofu format and validation
2. Docker image builds (without publish)
3. Security scanning

### Release Workflow (`release.yml`)

**Triggers:** Push to `main` branch

**What it does:**
1. Builds all Docker images in parallel
2. Publishes to GitHub Container Registry
3. Tags with `latest` and commit SHA

### Image Publishing

Images are published to GitHub Container Registry:
- **Registry**: `ghcr.io`
- **Organization**: `accuser-dev/atlas`
- **Format**: `ghcr.io/accuser-dev/atlas/<service>:<tag>`
- **Tags**: `latest` (main branch), commit SHA

**Making images public:**
After the first push, visit `https://github.com/accuser-dev/atlas/packages` and change each package visibility to public.

## Development

### Makefile Targets

```bash
make help              # Show all available commands

# Bootstrap (first time setup)
make bootstrap         # Set up remote state storage

# OpenTofu operations
make init              # Initialize OpenTofu with remote backend
make plan              # Plan infrastructure changes
make apply             # Apply infrastructure changes
make destroy           # Destroy infrastructure
make deploy            # Apply OpenTofu (pulls from ghcr.io)
make format            # Format OpenTofu files

# Docker operations
make build-all         # Build all Docker images locally (testing)
make build-<service>   # Build specific service image locally

# Cleanup
make clean             # Clean all build artifacts
make clean-docker      # Clean Docker cache
make clean-tofu        # Clean OpenTofu cache
make clean-images      # Remove Atlas images from Incus cache

# Backup operations
make backup-snapshot   # Create snapshots of all storage volumes
make backup-export     # Export all volumes to tarballs
make backup-list       # List all volume snapshots
```

### Directory Organization

- **`docker/`** - Custom Docker image definitions
  - Each service has its own directory with Dockerfile and README
  - Images are built by GitHub Actions and published to ghcr.io

- **`terraform/`** - Infrastructure as Code (OpenTofu)
  - `bootstrap/` - Remote state setup
  - `modules/` - Reusable service modules
  - `*.tf` - Root-level OpenTofu configuration
  - `terraform.tfvars` - Secrets and variables (gitignored)

## Troubleshooting

### Container not starting

Check container logs:
```bash
incus info <container-name>
incus console <container-name>
```

### OpenTofu state issues

View current state:
```bash
cd terraform
tofu show
```

### Network connectivity

Test internal DNS:
```bash
incus exec grafana01 -- ping prometheus01.incus
```

### Certificate issues

Check Caddy logs:
```bash
incus exec caddy01 -- cat /var/log/caddy.log
```

### Image pull errors

If Incus can't pull images from ghcr.io:
1. Verify images are public in GitHub packages settings
2. Check image names match expected format
3. Test pull manually: `incus launch ghcr:accuser-dev/atlas/grafana:latest test`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed contribution guidelines.

Quick start:
1. Create a feature branch from `main`
2. Make changes and test with `make plan`
3. Format code: `make format`
4. Submit pull request to `main`
5. GitHub Actions will validate and build images

## License

[Your license here]

## Additional Documentation

For detailed architecture, design patterns, and development guidance, see:
- [CLAUDE.md](CLAUDE.md) - Complete architecture documentation
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines and GitHub Flow
- [BACKUP.md](BACKUP.md) - Backup and disaster recovery procedures
- [GITOPS.md](GITOPS.md) - GitOps workflow with Atlantis
- [docker/*/README.md](docker/) - Service-specific Docker image docs
- [terraform/modules/*/](terraform/modules/) - OpenTofu module documentation
