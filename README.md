# Atlas Infrastructure

A Terraform-based infrastructure project for managing Incus containers running a complete observability and monitoring stack.

## Overview

This project provides a declarative infrastructure setup for:
- **Caddy** - Reverse proxy with automatic HTTPS
- **Grafana** - Visualization and dashboarding
- **Prometheus** - Metrics collection and storage
- **Loki** - Log aggregation

All services run in Incus containers with persistent storage, network isolation, and automatic configuration management.

## Project Structure

```
atlas/
├── docker/                    # Custom Docker images
│   ├── caddy/                # Reverse proxy with Cloudflare DNS plugin
│   ├── grafana/              # Grafana with optional plugins
│   ├── loki/                 # Log aggregation
│   └── prometheus/           # Metrics collection with optional rules
│
├── terraform/                 # Infrastructure as Code
│   ├── modules/              # Reusable service modules
│   │   ├── caddy/
│   │   ├── grafana/
│   │   ├── loki/
│   │   └── prometheus/
│   ├── main.tf               # Service instantiations
│   ├── networks.tf           # Network configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output values
│   └── terraform.tfvars      # Secrets (gitignored)
│
├── .github/workflows/        # CI/CD workflows
│   └── terraform-ci.yml      # Terraform validation and Docker builds
├── Makefile                  # Build and deployment automation
├── CLAUDE.md                 # Detailed architecture documentation
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- [Incus](https://linuxcontainers.org/incus/) installed and running
- [Terraform](https://www.terraform.io/) >= 1.0
- Cloudflare API token (for DNS-01 ACME challenges)
- GitHub account (images published to ghcr.io)

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/accuser/atlas.git
   cd atlas
   ```

2. **Create terraform.tfvars**:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit with your values:
   # - cloudflare_api_token
   # - network addresses (IPv4)
   ```

3. **Deploy infrastructure**:
   ```bash
   make terraform-init
   make terraform-plan
   make terraform-apply
   ```

   Or use the combined command:
   ```bash
   make deploy
   ```

4. **View outputs**:
   ```bash
   cd terraform
   terraform output
   ```

## Docker Images

### Production Images (GitHub Container Registry)

All services use custom images automatically built and published by GitHub Actions:

- **Caddy**: `ghcr.io/accuser/atlas/caddy:latest`
- **Grafana**: `ghcr.io/accuser/atlas/grafana:latest`
- **Loki**: `ghcr.io/accuser/atlas/loki:latest`
- **Prometheus**: `ghcr.io/accuser/atlas/prometheus:latest`

Images are:
- Built on every push to `main` or `develop`
- Published to GitHub Container Registry (ghcr.io)
- Publicly accessible (no authentication required)
- Extended from official images with custom plugins and configuration

### Local Development

Build images locally for testing:
```bash
make build-all           # Build all images
make build-grafana       # Build specific service
```

List local images:
```bash
make list-images
```

**Note:** Local builds are for testing only. Production deployments use images from ghcr.io.

## Usage

### Managing Infrastructure

Initialize Terraform:
```bash
make terraform-init
```

Plan changes:
```bash
make terraform-plan
```

Apply changes:
```bash
make terraform-apply
```

Destroy infrastructure:
```bash
make terraform-destroy
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
4. Push to GitHub (main or develop branch)
5. GitHub Actions builds and publishes to ghcr.io
6. Run `make terraform-apply` to pull new image

### Network Configuration

Three networks are defined in `terraform/networks.tf`:
- **development** - For dev/staging services
- **testing** - For test environments
- **production** - For production services (default)

Configure IP addresses in `terraform/terraform.tfvars`.

### Adding New Services

See [CLAUDE.md](CLAUDE.md#adding-new-service-modules) for detailed instructions on adding new services.

## Architecture

### Key Features

- **Declarative Infrastructure** - Everything defined in Terraform
- **Modular Design** - Reusable service modules
- **CI/CD Integration** - Automated image builds via GitHub Actions
- **Custom Images** - Published to GitHub Container Registry
- **Persistent Storage** - Data survives container restarts
- **Automatic HTTPS** - Let's Encrypt via Cloudflare DNS
- **Network Isolation** - Separate networks for different environments
- **Dynamic Configuration** - Auto-generated reverse proxy configs

### Service Architecture

```
Internet
    ↓
[Caddy Reverse Proxy] ← HTTPS certificates via Cloudflare
    ↓
[Grafana] → [Prometheus] → Metrics
          ↘ [Loki]       → Logs
```

**Public Services** (via Caddy):
- Grafana: `https://grafana.accuser.dev`

**Internal Services** (Incus network only):
- Prometheus: `http://prometheus01.incus:9090`
- Loki: `http://loki01.incus:3100`

### Storage Volumes

Persistent storage for each service:
- `grafana01-data` (10GB) - Dashboards and settings
- `loki01-data` (50GB) - Log storage
- `prometheus01-data` (100GB) - Metrics storage

## CI/CD

The project includes GitHub Actions workflows for continuous integration:

### Terraform CI Workflow

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Only when relevant files change (`.tf`, `.tftpl`, `Dockerfile`)

**What it does:**
1. **Terraform Validation** - Validates format, initialization, and configuration
2. **Docker Build and Publish** - Builds all four images and publishes to ghcr.io (on push to main/develop)
3. **Terraform Plan** - Generates a plan preview (dry run)
4. **PR Comments** - Posts plan results on pull requests

**Performance optimizations:**
- Fast validation checks run first to fail fast
- Docker images build in parallel (4 concurrent jobs)
- GitHub Actions cache for faster rebuilds
- Only publishes on push to main/develop (not on PRs)

**Workflow file:** [.github/workflows/terraform-ci.yml](.github/workflows/terraform-ci.yml)

### Image Publishing

Images are published to GitHub Container Registry:
- **Registry**: `ghcr.io`
- **Organization**: `accuser/atlas`
- **Format**: `ghcr.io/accuser/atlas/<service>:<tag>`
- **Tags**: `latest` (main branch), `develop` (develop branch), commit SHA

**Making images public:**
After the first push, visit `https://github.com/accuser/atlas/packages` and change each package visibility to public.

## Development

### Makefile Targets

```bash
make help              # Show all available commands
make build-all         # Build all Docker images locally (testing)
make build-<service>   # Build specific service image locally
make terraform-init    # Initialize Terraform
make terraform-plan    # Plan infrastructure changes
make terraform-apply   # Apply infrastructure changes
make terraform-destroy # Destroy infrastructure
make deploy            # Apply Terraform (pulls from ghcr.io)
make clean             # Clean build artifacts
make clean-docker      # Clean Docker cache
make clean-terraform   # Clean Terraform cache
make format            # Format Terraform files
```

### Directory Organization

- **`docker/`** - Custom Docker image definitions
  - Each service has its own directory with Dockerfile and README
  - Images are built by GitHub Actions and published to ghcr.io

- **`terraform/`** - Infrastructure as Code
  - `modules/` - Reusable service modules
  - `*.tf` - Root-level Terraform configuration
  - `terraform.tfvars` - Secrets and variables (gitignored)

## Troubleshooting

### Container not starting

Check container logs:
```bash
incus info <container-name>
incus console <container-name>
```

### Terraform state issues

View current state:
```bash
cd terraform
terraform show
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
3. Test pull manually: `incus launch docker:ghcr.io/accuser/atlas/grafana:latest test`

## Contributing

1. Make changes in a feature branch
2. Test with `make terraform-plan`
3. Format code: `make format`
4. Submit pull request
5. GitHub Actions will validate and build images

## License

[Your license here]

## Additional Documentation

For detailed architecture, design patterns, and development guidance, see:
- [CLAUDE.md](CLAUDE.md) - Complete architecture documentation
- [docker/*/README.md](docker/) - Service-specific Docker image docs
- [terraform/modules/*/](terraform/modules/) - Terraform module documentation
