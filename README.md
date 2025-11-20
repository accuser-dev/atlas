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

3. **Build and import Docker images** (optional, uses official images by default):
   ```bash
   # Build images and import to Incus
   make import-all

   # Or just build without importing
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

### Building and Importing Custom Images

Build and import all images to Incus:
```bash
make import-all
```

Import specific services:
```bash
make import-caddy
make import-grafana
make import-loki
make import-prometheus
```

Build without importing (for testing):
```bash
make build-all
make build-grafana  # etc.
```

List imported images:
```bash
make list-images
```

**How it works:** Images are built with Docker, exported as tarballs, and imported into Incus with aliases like `atlas-grafana`. See [docker/README.md](docker/README.md) for details.

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

To use custom images:

1. **Import images to Incus**:
   ```bash
   make import-all
   ```

2. **Update Terraform** to use the imported image in `terraform/main.tf`:
   ```hcl
   module "grafana01" {
     source = "./modules/grafana"

     image = "atlas-grafana"  # Use imported Incus image alias
     # ... other configuration
   }
   ```

3. **Apply changes**:
   ```bash
   cd terraform
   terraform apply
   ```

**Image aliases after import:**
- `atlas-caddy`
- `atlas-grafana`
- `atlas-loki`
- `atlas-prometheus`

See [docker/README.md](docker/README.md) for detailed information on image management.

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
1. **Terraform Validation** (fast) - Validates format, initialization, and configuration
2. **Docker Build** (parallel) - Builds all four images concurrently using matrix strategy
3. **Terraform Plan** - Generates a plan preview (dry run)
4. **PR Comments** - Posts plan results on pull requests

**Performance optimizations:**
- Cheap validation checks run first to fail fast
- Docker images build in parallel (4 concurrent jobs)
- Per-service GitHub Actions cache for faster rebuilds
- Prevents expensive Docker builds if Terraform validation fails

**Workflow file:** [.github/workflows/terraform-ci.yml](.github/workflows/terraform-ci.yml)

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
