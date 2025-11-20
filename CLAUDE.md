# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform infrastructure project that manages Incus containers for a complete monitoring stack including Caddy reverse proxy, Grafana, Prometheus, and Loki. The setup provisions containerized services with automatic HTTPS certificate management, persistent storage, and dynamic configuration generation.

The project is organized into two main directories:
- **`docker/`** - Custom Docker images for each service
- **`terraform/`** - Infrastructure as Code using Terraform

## Project Structure

```
atlas/
├── docker/                    # Custom Docker images
│   ├── caddy/                # Caddy reverse proxy with Cloudflare DNS
│   │   ├── Dockerfile
│   │   └── README.md
│   ├── grafana/              # Grafana with optional plugins
│   │   ├── Dockerfile
│   │   └── README.md
│   ├── loki/                 # Loki log aggregation
│   │   ├── Dockerfile
│   │   └── README.md
│   └── prometheus/           # Prometheus metrics collection
│       ├── Dockerfile
│       └── README.md
├── terraform/                 # Terraform infrastructure
│   ├── modules/              # Reusable Terraform modules
│   │   ├── caddy/
│   │   ├── grafana/
│   │   ├── loki/
│   │   └── prometheus/
│   ├── main.tf               # Module instantiations
│   ├── variables.tf          # Variable definitions
│   ├── networks.tf           # Network configuration
│   ├── outputs.tf            # Output values
│   ├── providers.tf          # Provider configuration
│   ├── versions.tf           # Version constraints
│   └── terraform.tfvars      # Variable values (gitignored)
├── Makefile                  # Build and deployment automation
└── CLAUDE.md                 # This file
```

## Common Commands

### Build and Deployment (Makefile)
```bash
# Build Docker images locally (for testing only)
make build-all
make build-caddy
make build-grafana
make build-loki
make build-prometheus

# Terraform operations
make terraform-init      # Initialize Terraform
make terraform-plan      # Plan changes
make terraform-apply     # Apply changes
make terraform-destroy   # Destroy infrastructure

# Complete deployment (applies Terraform, pulls images from ghcr.io)
make deploy

# Cleanup
make clean               # Clean all build artifacts
make clean-docker        # Clean Docker build cache
make clean-terraform     # Clean Terraform cache

# Format Terraform files
make format
```

**Note:** Production images are built and published automatically via GitHub Actions to `ghcr.io/accuser/atlas/*:latest`. Local builds are only needed for development/testing.

### Direct Terraform Operations
```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform (required first time or after provider changes)
terraform init

# Validate configuration
terraform validate

# Plan changes (see what will be applied)
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# Format Terraform files
terraform fmt -recursive

# Show current state
terraform show

# View outputs (endpoints, configurations)
terraform output
```

### Docker Image Management

**Production Images (GitHub Container Registry):**

Images are automatically built and published by GitHub Actions when code is pushed to `main` or `develop` branches:
- Caddy: `ghcr.io/accuser/atlas/caddy:latest`
- Grafana: `ghcr.io/accuser/atlas/grafana:latest`
- Loki: `ghcr.io/accuser/atlas/loki:latest`
- Prometheus: `ghcr.io/accuser/atlas/prometheus:latest`

**Local Development:**
```bash
# Build images locally for testing
make build-all
IMAGE_TAG=v1.0.0 make build-all
```

### Working with tfvars
The `terraform/terraform.tfvars` file contains sensitive variables and is gitignored. Required variables:
- `cloudflare_api_token`: Cloudflare API token for DNS management
- Network configuration variables (IPv4 addresses for development, testing, production networks)

## Architecture

### Modular Structure

The project uses Terraform modules for scalability and reusability:

**Terraform Root Level:**
- [terraform/versions.tf](terraform/versions.tf) - Terraform and provider version constraints
- [terraform/providers.tf](terraform/providers.tf) - Provider configuration
- [terraform/variables.tf](terraform/variables.tf) - Root-level input variable definitions
- [terraform/main.tf](terraform/main.tf) - Module instantiations and orchestration
- [terraform/networks.tf](terraform/networks.tf) - Network definitions (development, testing, production)
- [terraform/outputs.tf](terraform/outputs.tf) - Output values (endpoints, configurations)
- [terraform/terraform.tfvars](terraform/terraform.tfvars) - Variable values (gitignored, contains secrets)

**Terraform Modules:**
- [terraform/modules/caddy/](terraform/modules/caddy/) - Reverse proxy with dynamic Caddyfile generation
  - [main.tf](terraform/modules/caddy/main.tf) - Profile, container, and Caddyfile templating
  - [variables.tf](terraform/modules/caddy/variables.tf) - Module input variables
  - [outputs.tf](terraform/modules/caddy/outputs.tf) - Module outputs
  - [templates/Caddyfile.tftpl](terraform/modules/caddy/templates/Caddyfile.tftpl) - Caddyfile template
  - [versions.tf](terraform/modules/caddy/versions.tf) - Provider requirements

- [terraform/modules/grafana/](terraform/modules/grafana/) - Grafana observability platform
  - [main.tf](terraform/modules/grafana/main.tf) - Profile, container, and storage volume
  - [variables.tf](terraform/modules/grafana/variables.tf) - Module input variables including domain config
  - [outputs.tf](terraform/modules/grafana/outputs.tf) - Module outputs including Caddy config block
  - [templates/caddyfile.tftpl](terraform/modules/grafana/templates/caddyfile.tftpl) - Caddy reverse proxy template
  - [versions.tf](terraform/modules/grafana/versions.tf) - Provider requirements

- [terraform/modules/loki/](terraform/modules/loki/) - Log aggregation system (internal only)
  - [main.tf](terraform/modules/loki/main.tf) - Profile, container, and storage volume
  - [variables.tf](terraform/modules/loki/variables.tf) - Module input variables
  - [outputs.tf](terraform/modules/loki/outputs.tf) - Module outputs including endpoint
  - [versions.tf](terraform/modules/loki/versions.tf) - Provider requirements

- [terraform/modules/prometheus/](terraform/modules/prometheus/) - Metrics collection and storage (internal only)
  - [main.tf](terraform/modules/prometheus/main.tf) - Profile, container, storage volume, and config file
  - [variables.tf](terraform/modules/prometheus/variables.tf) - Module input variables including prometheus.yml config
  - [outputs.tf](terraform/modules/prometheus/outputs.tf) - Module outputs including endpoint
  - [versions.tf](terraform/modules/prometheus/versions.tf) - Provider requirements

**Docker Images:**
- [docker/caddy/](docker/caddy/) - Custom Caddy image with Cloudflare DNS plugin
  - [Dockerfile](docker/caddy/Dockerfile) - Image build definition
  - [README.md](docker/caddy/README.md) - Build and customization instructions

- [docker/grafana/](docker/grafana/) - Custom Grafana image with optional plugins
  - [Dockerfile](docker/grafana/Dockerfile) - Image build definition
  - [README.md](docker/grafana/README.md) - Plugin installation and provisioning guide

- [docker/loki/](docker/loki/) - Custom Loki image
  - [Dockerfile](docker/loki/Dockerfile) - Image build definition
  - [README.md](docker/loki/README.md) - Configuration instructions

- [docker/prometheus/](docker/prometheus/) - Custom Prometheus image with optional rules
  - [Dockerfile](docker/prometheus/Dockerfile) - Image build definition
  - [README.md](docker/prometheus/README.md) - Alert and recording rules guide

### Infrastructure Components

1. **Incus Provider** ([terraform/providers.tf](terraform/providers.tf), [terraform/versions.tf](terraform/versions.tf))
   - Uses the `lxc/incus` provider (v1.0.0+)
   - Manages LXC/Incus containers and storage volumes

2. **Network Configuration** ([terraform/networks.tf](terraform/networks.tf))
   - Three managed networks: development, testing, production
   - Each network has configurable IPv4 addresses
   - NAT enabled for external connectivity

3. **Caddy Module** ([terraform/modules/caddy/](terraform/modules/caddy/))
   - Reverse proxy with automatic HTTPS via Let's Encrypt
   - Dynamic Caddyfile generation from service module outputs
   - Cloudflare DNS-01 ACME challenge support
   - Dual network interfaces (production + management)
   - Accepts `service_blocks` list for dynamic configuration
   - Custom Docker image: [docker/caddy/](docker/caddy/)

4. **Caddy Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
   - Instance name: `caddy01`
   - Image: `ghcr.io/accuser/atlas/caddy:latest` (published from [docker/caddy/](docker/caddy/))
   - Resource limits: 2 CPUs, 1GB memory (configurable)
   - Dual network interfaces:
     - `eth0`: Connected to "production" network
     - `eth1`: Connected to "incusbr0" bridge
   - Caddyfile dynamically generated from module outputs

5. **Grafana Module** ([terraform/modules/grafana/](terraform/modules/grafana/))
   - Visualization and dashboarding platform
   - Persistent storage for dashboards and configuration (10GB)
   - Environment variable support for configuration
   - Generates Caddy reverse proxy configuration block
   - Domain-based access with IP restrictions
   - Custom Docker image: [docker/grafana/](docker/grafana/)

6. **Grafana Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
   - Instance name: `grafana01`
   - Image: `ghcr.io/accuser/atlas/grafana:latest` (published from [docker/grafana/](docker/grafana/))
   - Domain: `grafana.accuser.dev` (publicly accessible via Caddy)
   - Resource limits: 2 CPUs, 1GB memory
   - Storage: 10GB persistent volume for `/var/lib/grafana`
   - Network: Connected to production network

7. **Loki Module** ([terraform/modules/loki/](terraform/modules/loki/))
   - Log aggregation system (internal only)
   - Persistent storage for log data (50GB)
   - No public-facing reverse proxy configuration
   - Internal endpoint for Grafana data source
   - Custom Docker image: [docker/loki/](docker/loki/)

8. **Loki Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
   - Instance name: `loki01`
   - Image: `ghcr.io/accuser/atlas/loki:latest` (published from [docker/loki/](docker/loki/))
   - Internal endpoint: `http://loki01.incus:3100`
   - Resource limits: 2 CPUs, 2GB memory
   - Storage: 50GB persistent volume for `/loki`
   - Network: Connected to production network (internal only)

9. **Prometheus Module** ([terraform/modules/prometheus/](terraform/modules/prometheus/))
   - Metrics collection and time-series database (internal only)
   - Persistent storage for metrics data (100GB)
   - Optional prometheus.yml configuration file injection
   - No public-facing reverse proxy configuration
   - Internal endpoint for Grafana data source
   - Custom Docker image: [docker/prometheus/](docker/prometheus/)

10. **Prometheus Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `prometheus01`
    - Image: `ghcr.io/accuser/atlas/prometheus:latest` (published from [docker/prometheus/](docker/prometheus/))
    - Internal endpoint: `http://prometheus01.incus:9090`
    - Resource limits: 2 CPUs, 2GB memory
    - Storage: 100GB persistent volume for `/prometheus`
    - Network: Connected to production network (internal only)

### Dynamic Caddyfile Generation

The project uses a template-based approach for generating Caddyfile configurations:

1. **Service modules** (like Grafana) declare their domain and generate a Caddy config block via `caddy_config_block` output
2. **Root main.tf** collects all service blocks and passes them to the Caddy module as a list
3. **Caddy module** uses its internal template to combine service blocks with global configuration
4. **Result**: Automatically generated, consistent reverse proxy configuration

**Adding a new public service:**
```hcl
# In terraform/main.tf, add the service's caddy_config_block to the list
module "caddy01" {
  service_blocks = [
    module.grafana01.caddy_config_block,
    module.newservice01.caddy_config_block,  # Add here
  ]
}
```

### Storage Architecture

Each service with persistent storage uses Incus storage volumes:
- Automatically created by the module when `enable_data_persistence = true`
- Configurable size and name
- Mounted to service-specific paths in containers
- Survives container restarts and updates

**Current storage volumes:**
- `grafana01-data` - 10GB - `/var/lib/grafana`
- `loki01-data` - 50GB - `/loki`
- `prometheus01-data` - 100GB - `/prometheus`

### Adding New Service Modules

**For public-facing services (with Caddy reverse proxy):**

1. Create Docker image in `docker/yourservice/` with Dockerfile
2. Add service to GitHub Actions matrix in `.github/workflows/terraform-ci.yml`
3. Create Terraform module in `terraform/modules/yourservice/`
4. Add `domain`, `allowed_ip_range`, and port variables to module
5. Set default image to `docker:ghcr.io/accuser/atlas/yourservice:latest`
6. Create `templates/caddyfile.tftpl` for reverse proxy config
7. Add `caddy_config_block` output using templatefile()
8. Instantiate module in [terraform/main.tf](terraform/main.tf)
9. Add module's `caddy_config_block` to Caddy's `service_blocks` list
10. Push to GitHub to build and publish image

**For internal-only services (no public access):**

1. Create Docker image in `docker/yourservice/` with Dockerfile
2. Add service to GitHub Actions matrix in `.github/workflows/terraform-ci.yml`
3. Create Terraform module in `terraform/modules/yourservice/`
4. Set default image to `docker:ghcr.io/accuser/atlas/yourservice:latest`
5. Add storage and network configuration to module
6. Add endpoint output for internal connectivity
7. Instantiate module in [terraform/main.tf](terraform/main.tf)
8. Connect from other services using `yourservice.incus:port`
9. Push to GitHub to build and publish image

**Example - Adding a new Grafana instance:**

1. The Grafana image is already published to ghcr.io via GitHub Actions

2. Add to `terraform/main.tf`:
```hcl
module "grafana02" {
  source = "./modules/grafana"

  instance_name = "grafana02"
  profile_name  = "grafana02"

  monitoring_network = incus_network.production.name

  domain           = "grafana-dev.accuser.dev"
  allowed_ip_range = "192.168.68.0/22"

  # Uses ghcr.io image by default (docker:ghcr.io/accuser/atlas/grafana:latest)
  # Optional: Override to use official image
  # image = "docker:grafana/grafana:latest"

  environment_variables = {
    GF_SECURITY_ADMIN_USER     = "admin"
    GF_SECURITY_ADMIN_PASSWORD = "secure-password"
  }

  enable_data_persistence = true
  data_volume_name        = "grafana02-data"
  data_volume_size        = "10GB"

  depends_on = [incus_network.production]
}

# Add to Caddy's service_blocks
module "caddy01" {
  service_blocks = [
    module.grafana01.caddy_config_block,
    module.grafana02.caddy_config_block,  # Add here
  ]
}
```

### Key Design Patterns

**Modular Architecture:**
- Each service type has its own Docker image in `docker/`
- Each service type has its own Terraform module in `terraform/modules/`
- Modules are instantiated in the root [terraform/main.tf](terraform/main.tf)
- Easy to scale by adding new module instances
- Module parameters allow customization per instance

**Container Configuration Flow:**
1. Module defines profile with resource limits and network connectivity
2. Module creates storage volume (if persistence enabled)
3. Module creates container that references the profile
4. Module injects configuration files and environment variables
5. Root module orchestrates dependencies and network setup

**Dynamic Configuration:**
- Services declare their own reverse proxy configuration
- Caddy module assembles configurations into complete Caddyfile
- Type-safe: All values validated by Terraform
- DRY principle: No duplicate configuration

**Network Architecture:**
- Three environments: development, testing, production
- Services on same network can communicate via internal DNS
- Public services exposed via Caddy reverse proxy
- IP-based access control for security
- Automatic HTTPS via Let's Encrypt with Cloudflare DNS validation

**Storage Management:**
- Each service module manages its own storage volume
- Conditionally created based on `enable_data_persistence`
- Configurable size per instance
- Proper lifecycle management by Terraform

### Monitoring Stack Integration

The complete observability stack is designed to work together:

1. **Grafana** (public) - Visualization frontend
   - Access: `https://grafana.accuser.dev`
   - Connects to Prometheus and Loki as data sources

2. **Prometheus** (internal) - Metrics storage
   - Endpoint: `http://prometheus01.incus:9090`
   - Scrapes metrics from applications
   - Queried by Grafana for metric visualization

3. **Loki** (internal) - Log aggregation
   - Endpoint: `http://loki01.incus:3100`
   - Receives logs from applications
   - Queried by Grafana for log exploration

**Configuring Grafana data sources:**
```yaml
# Add in Grafana UI or via provisioning:
# Prometheus: http://prometheus01.incus:9090
# Loki: http://loki01.incus:3100
```

## Workflow

### Development Workflow

1. **Customize Docker images** (optional):
   - Edit Dockerfiles in `docker/*/Dockerfile`
   - Add plugins, configuration files, or customizations
   - Test locally: `make build-<service>`
   - Push to GitHub to trigger CI/CD build and publish

2. **Configure Infrastructure**:
   - Edit Terraform modules in `terraform/modules/`
   - Modify main configuration in `terraform/main.tf`
   - Update variables in `terraform/terraform.tfvars`

3. **Deploy**:
   ```bash
   # Deploy infrastructure (pulls images from ghcr.io)
   make deploy

   # Or step-by-step
   make terraform-init
   make terraform-plan
   make terraform-apply
   ```

4. **Verify**:
   ```bash
   cd terraform && terraform output
   ```

### Docker Image Configuration

**Default: GitHub Container Registry Images**

All modules are configured to use custom images published to GitHub Container Registry:
- Caddy: `docker:ghcr.io/accuser/atlas/caddy:latest`
- Grafana: `docker:ghcr.io/accuser/atlas/grafana:latest`
- Loki: `docker:ghcr.io/accuser/atlas/loki:latest`
- Prometheus: `docker:ghcr.io/accuser/atlas/prometheus:latest`

These images are:
- Built automatically by GitHub Actions on push to main/develop
- Published to GitHub Container Registry (ghcr.io)
- Extended from official images with custom plugins and configuration
- Publicly accessible (no authentication required)

**Image Publishing Workflow:**

1. Edit Dockerfile in `docker/*/Dockerfile`
2. Push changes to `main` or `develop` branch
3. GitHub Actions builds and publishes to ghcr.io
4. Terraform pulls latest image on next apply

**Switching to Official Images**

To use official upstream images instead, override the `image` variable in [terraform/main.tf](terraform/main.tf):

```hcl
module "grafana01" {
  source = "./modules/grafana"

  # Use official image instead of custom ghcr.io image
  image = "docker:grafana/grafana:latest"

  # ... other configuration
}
```

### Post-Creation Configuration

**For Docker containers**:
- ✅ **Custom Docker images** - Pre-install packages and plugins (recommended)
- ✅ **Environment variables** - Configure at runtime via Terraform
- ✅ **File injection** - Use Terraform `file` blocks for configuration files
- ⚠️ **External scripts** - Use `incus exec` via separate orchestration script
- ❌ **Terraform provisioners** - Avoid (fragile and non-declarative)
- ❌ **Cloud-init** - Not available for Docker protocol images

**For system containers** (future use):
- ✅ **Cloud-init** - Use when launching system container images (`images:ubuntu/22.04`)
- ✅ **Custom images** - Pre-configure with Packer or image builds

## Important Notes

- The `terraform/terraform.tfvars` file is gitignored and must be created manually with required secrets
- All services use custom images published to GitHub Container Registry (ghcr.io) by default
- Images are automatically built and published by GitHub Actions on push to main/develop
- Access to services is restricted to the 192.168.68.0/22 subnet by default
- All services use the `production` network for connectivity
- Storage volumes use the `local` storage pool and are created automatically when modules are applied
- Each module has a `versions.tf` specifying the Incus provider requirement
- Images must be public in GitHub Container Registry for Incus to pull without authentication

## Outputs

After applying, use `cd terraform && terraform output` to view:
- `grafana_caddy_config` - Generated Caddy configuration for Grafana
- `loki_endpoint` - Internal Loki endpoint URL
- `prometheus_endpoint` - Internal Prometheus endpoint URL
