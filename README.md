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
- [Docker](https://www.docker.com/) (for building custom images)
- Cloudflare API token (for DNS-01 ACME challenges)

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd atlas
   ```

2. **Create terraform.tfvars**:
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit with your values:
   # - cloudflare_api_token
   # - network addresses (IPv4/IPv6)
   ```

3. **Build Docker images** (optional, uses official images by default):
   ```bash
   cd ..
   make build-all
   ```

4. **Initialize and apply Terraform**:
   ```bash
   make terraform-init
   make terraform-plan
   make terraform-apply
   ```

   Or use the combined command:
   ```bash
   make deploy
   ```

5. **View outputs**:
   ```bash
   cd terraform
   terraform output
   ```

## Usage

### Building Custom Images

Build all images:
```bash
make build-all
```

Build specific services:
```bash
make build-caddy
make build-grafana
make build-loki
make build-prometheus
```

Build with custom tags:
```bash
IMAGE_TAG=v1.0.0 make build-all
```

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

Build images and deploy in one command:
```bash
make deploy
```

## Configuration

### Using Custom vs Official Images

By default, the project uses official Docker images:
- `docker:caddybuilds/caddy-cloudflare`
- `docker:grafana/grafana`
- `docker:grafana/loki`
- `docker:prom/prometheus`

To use custom images, modify the `image` parameter in `terraform/main.tf`:
```hcl
module "grafana01" {
  source = "./modules/grafana"

  image = "docker:atlas/grafana:latest"  # Custom image
  # ... other configuration
}
```

### Customizing Docker Images

1. Edit the Dockerfile in `docker/<service>/Dockerfile`
2. Add plugins, configuration, or customizations
3. Rebuild: `make build-<service>`
4. Update Terraform to reference the custom image
5. Apply: `make terraform-apply`

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
- **Custom Images** - Optional Docker customization
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
- `caddy01-data` - Caddy certificates and configuration
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
1. **Docker Build Validation** - Builds all four Docker images to ensure they compile
2. **Terraform Checks** - Validates format, initialization, and configuration
3. **Plan Preview** - Generates a Terraform plan (dry run)
4. **PR Comments** - Posts validation results on pull requests

**Workflow file:** [.github/workflows/terraform-ci.yml](.github/workflows/terraform-ci.yml)

All Terraform commands run in the `terraform/` directory, and Docker builds use GitHub Actions cache for faster builds.

## Post-Creation Configuration

This project follows Terraform best practices for container configuration:

✅ **Recommended approaches**:
- Custom Docker images (pre-install plugins, packages)
- Environment variables (runtime configuration)
- Terraform file injection (config files)

⚠️ **Use with caution**:
- External orchestration scripts (`incus exec`)

❌ **Avoid**:
- Terraform provisioners (fragile, non-declarative)
- Cloud-init (not available for Docker containers)

See [CLAUDE.md](CLAUDE.md#post-creation-configuration) for detailed guidance.

## Development

### Makefile Targets

```bash
make help              # Show all available commands
make build-all         # Build all Docker images
make build-<service>   # Build specific service image
make terraform-init    # Initialize Terraform
make terraform-plan    # Plan infrastructure changes
make terraform-apply   # Apply infrastructure changes
make terraform-destroy # Destroy infrastructure
make deploy            # Build all + apply
make clean             # Clean build artifacts
make clean-docker      # Clean Docker cache
make clean-terraform   # Clean Terraform cache
make format            # Format Terraform files
```

### Directory Organization

- **`docker/`** - Custom Docker image definitions
  - Each service has its own directory with Dockerfile and README
  - Images are tagged as `atlas/<service>:latest` by default

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

## Contributing

1. Make changes in a feature branch
2. Test with `make terraform-plan`
3. Format code: `make format`
4. Submit pull request

## License

[Your license here]

## Additional Documentation

For detailed architecture, design patterns, and development guidance, see:
- [CLAUDE.md](CLAUDE.md) - Complete architecture documentation
- [docker/*/README.md](docker/) - Service-specific Docker image docs
- [terraform/modules/*/](terraform/modules/) - Terraform module documentation
