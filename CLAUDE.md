# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform infrastructure project that manages Incus containers for a complete monitoring stack including Caddy reverse proxy, Grafana, Prometheus, and Loki. The setup provisions containerized services with automatic HTTPS certificate management, persistent storage, and dynamic configuration generation.

The project is organized into two main directories:
- **`docker/`** - Custom Docker images for each service
- **`terraform/`** - Infrastructure as Code using Terraform

## Resource Requirements

### Compute Resources

| Service | CPU (cores) | Memory | Purpose |
|---------|-------------|--------|---------|
| Caddy | 2 | 1GB | Reverse proxy, TLS termination |
| Grafana | 2 | 1GB | Dashboards, visualization |
| Prometheus | 2 | 2GB | Metrics storage |
| Loki | 2 | 2GB | Log aggregation |
| Alertmanager | 1 | 256MB | Alert routing |
| step-ca | 1 | 512MB | Certificate authority |
| Node Exporter | 1 | 128MB | Host metrics |
| Mosquitto | 1 | 256MB | MQTT broker |
| Cloudflared | 1 | 256MB | Tunnel client (optional) |
| **Total** | **13** | **7.4GB** | |

**Notes:**
- Resource limits are enforced with hard memory limits (OOM kill on exceed)
- CPU values are soft limits (can burst if host has capacity)
- Cloudflared is conditionally deployed (only when tunnel token is set)

### Storage Requirements

| Volume | Default Size | Growth Rate | Purpose |
|--------|--------------|-------------|---------|
| prometheus01-data | 100GB | ~1GB/day* | Metrics retention (30d default) |
| loki01-data | 50GB | ~500MB/day* | Log retention (30d default) |
| grafana01-data | 10GB | Minimal | Dashboards, plugins |
| alertmanager01-data | 1GB | Minimal | Silences, notifications |
| step-ca01-data | 1GB | Minimal | CA certificates, database |
| mosquitto01-data | 5GB | Variable | Retained MQTT messages |
| **Total** | **167GB** | | |

*Growth rates vary significantly based on workload. Adjust retention settings to control storage usage.

### Network Requirements

| Network | CIDR | Purpose |
|---------|------|---------|
| development | 10.10.0.0/24 | Development workloads |
| testing | 10.20.0.0/24 | Testing workloads |
| staging | 10.30.0.0/24 | Staging workloads |
| production | 10.40.0.0/24 | Production applications |
| management | 10.50.0.0/24 | Internal services (monitoring) |

**External Access:**
- Caddy: Ports 80, 443 (HTTP/HTTPS)
- Mosquitto: Ports 1883, 8883 (MQTT/MQTTS)
- Cloudflared: Outbound only (no inbound ports)

### Minimum Host Requirements

For a complete deployment with all services:

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 8GB | 16GB |
| Storage | 200GB | 500GB |
| Network | 1 interface | 1 interface |

**Notes:**
- Containers share host resources; minimums assume light workload
- Production deployments should size based on expected metrics/log volume
- Storage should be on SSD for Prometheus/Loki performance

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
│   ├── prometheus/           # Prometheus metrics collection
│   │   ├── Dockerfile
│   │   └── README.md
│   ├── mosquitto/            # Eclipse Mosquitto MQTT broker
│   │   ├── Dockerfile
│   │   └── README.md
│   ├── cloudflared/          # Cloudflare Tunnel client for Zero Trust
│   │   ├── Dockerfile
│   │   └── README.md
│   └── step-ca/              # Internal ACME CA for TLS certificates
│       ├── Dockerfile
│       └── README.md
├── terraform/                 # Terraform infrastructure
│   ├── bootstrap/            # Bootstrap Terraform project
│   │   ├── main.tf           # Creates storage bucket and credentials
│   │   ├── variables.tf      # Bootstrap variables
│   │   ├── outputs.tf        # Bootstrap outputs
│   │   ├── versions.tf       # Version constraints (local state)
│   │   └── README.md         # Bootstrap documentation
│   ├── modules/              # Reusable Terraform modules
│   │   ├── caddy/
│   │   ├── cloudflared/
│   │   ├── grafana/
│   │   ├── incus-loki/
│   │   ├── incus-metrics/
│   │   ├── loki/
│   │   ├── mosquitto/
│   │   ├── prometheus/
│   │   └── step-ca/
│   ├── init.sh               # Initialization wrapper script
│   ├── main.tf               # Module instantiations
│   ├── variables.tf          # Variable definitions
│   ├── networks.tf           # Network configuration
│   ├── outputs.tf            # Output values
│   ├── providers.tf          # Provider configuration
│   ├── versions.tf           # Version constraints and backend config
│   ├── README.md             # Terraform usage documentation
│   ├── terraform.tfvars      # Variable values (gitignored)
│   ├── backend.hcl           # Backend credentials (gitignored)
│   ├── backend.hcl.example   # Backend config template
│   └── BACKEND_SETUP.md      # Remote state setup guide
├── Makefile                  # Build and deployment automation
├── CONTRIBUTING.md           # Contribution guidelines and GitHub Flow workflow
├── BACKUP.md                 # Backup and disaster recovery procedures
└── CLAUDE.md                 # This file
```

## Common Commands

### First-Time Setup (Fresh Incus Installation)

For a vanilla Incus installation (after `incus admin init`):

```bash
# 1. Bootstrap (creates storage bucket for Terraform state)
make bootstrap

# 2. Initialize OpenTofu with remote backend
make init

# 3. Deploy infrastructure
make deploy
```

### Build and Deployment (Makefile)
```bash
# Bootstrap commands (run once for fresh setup)
make bootstrap           # Complete bootstrap process
make bootstrap-init      # Initialize bootstrap Terraform
make bootstrap-plan      # Plan bootstrap changes
make bootstrap-apply     # Apply bootstrap

# Build Docker images locally (for testing only)
make build-all
make build-caddy
make build-grafana
make build-loki
make build-prometheus

# OpenTofu operations (after bootstrap)
make init                # Initialize OpenTofu with remote backend
make plan                # Plan changes
make apply               # Apply changes
make destroy             # Destroy infrastructure and remove cached images

# Complete deployment (applies OpenTofu, pulls images from ghcr.io)
make deploy

# Cleanup
make clean               # Clean all build artifacts
make clean-docker        # Clean Docker build cache
make clean-tofu          # Clean OpenTofu cache
make clean-bootstrap     # Clean bootstrap OpenTofu cache
make clean-images        # Remove Atlas images from Incus cache

# Format OpenTofu files
make format

# Backup operations
make backup-snapshot     # Create snapshots of all storage volumes
make backup-export       # Export all volumes to tarballs (stops services)
make backup-list         # List all volume snapshots
```

**Note:** Production images are built and published automatically via GitHub Actions to `ghcr.io/accuser/atlas/*:latest`. Local builds are only needed for development/testing.

For detailed backup procedures and disaster recovery playbooks, see [BACKUP.md](BACKUP.md).

### Direct OpenTofu Operations

**Important:** Do not run `tofu init` directly - it requires backend configuration. Use one of these methods:

```bash
# Option 1: Use the Makefile (recommended)
make init

# Option 2: Use the init wrapper script
cd terraform && ./init.sh

# Option 3: Manual with backend config
cd terraform && tofu init -backend-config=backend.hcl
```

After initialization, you can run other commands directly:
```bash
cd terraform

# Validate configuration
tofu validate

# Plan changes (see what will be applied)
tofu plan

# Apply changes
tofu apply

# Destroy infrastructure
tofu destroy

# Format Terraform files
tofu fmt -recursive

# Show current state
tofu show

# View outputs (endpoints, configurations)
tofu output
```

### Terraform State Management

**Remote State Backend:**

This project uses Incus S3-compatible storage buckets for encrypted remote state storage. This provides:
- Encrypted state at rest
- Self-hosted (no external dependencies)
- S3-compatible API
- Secure credential-based access

**Bootstrap Process:**

The project uses a **two-project structure**:
1. **Bootstrap project** (`terraform/bootstrap/`) - Uses local state, creates storage bucket
2. **Main project** (`terraform/`) - Uses remote state in the storage bucket

**Initial Setup (Automated):**

```bash
# Run bootstrap to set up storage bucket
make bootstrap

# Bootstrap creates:
# - Incus storage buckets configuration
# - Storage pool (terraform-state)
# - Storage bucket (atlas-terraform-state)
# - S3 credentials
# - Backend config file (terraform/backend.hcl)
```

See [terraform/BACKEND_SETUP.md](terraform/BACKEND_SETUP.md) for detailed instructions and [terraform/bootstrap/README.md](terraform/bootstrap/README.md) for bootstrap documentation.

**Working with Remote State:**

```bash
# Normal operations work the same
cd terraform
tofu plan
tofu apply

# State is automatically stored remotely
tofu state list

# Migrate existing local state (if needed)
tofu init -migrate-state
```

**Important Notes:**
- Never commit `backend.hcl` (gitignored)
- Store S3 credentials securely (environment variables recommended)
- For CI/CD, use GitHub Secrets for credentials
- Backup storage bucket regularly for disaster recovery

### Docker Image Management

**Production Images (GitHub Container Registry):**

Images are automatically built and published by GitHub Actions when code is pushed to the `main` branch:
- Caddy: `ghcr.io/accuser/atlas/caddy:latest`
- Cloudflared: `ghcr.io/accuser/atlas/cloudflared:latest`
- Grafana: `ghcr.io/accuser/atlas/grafana:latest`
- Loki: `ghcr.io/accuser/atlas/loki:latest`
- Mosquitto: `ghcr.io/accuser/atlas/mosquitto:latest`
- Prometheus: `ghcr.io/accuser/atlas/prometheus:latest`
- step-ca: `ghcr.io/accuser/atlas/step-ca:latest`

**Local Development:**
```bash
# Build images locally for testing
make build-all
IMAGE_TAG=v1.0.0 make build-all
```

### Working with tfvars
The `terraform/terraform.tfvars` file contains sensitive variables and is gitignored. Required variables:
- `cloudflare_api_token`: Cloudflare API token for DNS management
- Network configuration variables (IPv4 addresses for development, testing, staging, production, and management networks)

## Development Workflow

### GitHub Flow

This project uses **GitHub Flow** for development. All work happens on feature branches created from and merged back to `main`.

**Branch Structure:**
- `main` - Production-ready code (protected)
- `feature/*`, `fix/*`, `docs/*` - Short-lived branches for specific work

**Quick Start:**
```bash
# Start new work
git checkout main
git pull origin main
git checkout -b feature/issue-X-description

# Make changes, commit, and push
git add .
git commit -m "fix: description of change

Fixes #X"
git push -u origin feature/issue-X-description

# Create PR targeting main
gh pr create --base main --title "Fix: Description" --body "Fixes #X"
```

**Important Notes:**
- Always branch from `main`
- Always target `main` in pull requests
- Link issues with "Fixes #X" in PR descriptions
- Wait for CI checks to pass before merging
- Delete feature branches after merging

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed workflow guidelines.

## Architecture

### Modular Structure

The project uses Terraform modules for scalability and reusability:

**Terraform Root Level:**
- [terraform/versions.tf](terraform/versions.tf) - Terraform and provider version constraints
- [terraform/providers.tf](terraform/providers.tf) - Provider configuration
- [terraform/variables.tf](terraform/variables.tf) - Root-level input variable definitions
- [terraform/main.tf](terraform/main.tf) - Module instantiations and orchestration
- [terraform/networks.tf](terraform/networks.tf) - Network definitions (development, testing, staging, production, management)
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
   - Five managed networks: development, testing, staging, production, management
   - Each network has configurable IPv4 addresses (default 10.10.0.1/24 through 10.50.0.1/24)
   - Optional IPv6 support (dual-stack) using ULA addresses (e.g., fd00:10:10::1/64)
   - NAT enabled for external connectivity (configurable for both IPv4 and IPv6)
   - Management network (10.50.0.1/24) hosts internal services like monitoring

3. **Caddy Module** ([terraform/modules/caddy/](terraform/modules/caddy/))
   - Reverse proxy with automatic HTTPS via Let's Encrypt
   - Dynamic Caddyfile generation from service module outputs
   - Cloudflare DNS-01 ACME challenge support
   - Rate limiting protection (mholt/caddy-ratelimit plugin)
   - Triple network interfaces (production + management + external)
   - Accepts `service_blocks` list for dynamic configuration
   - Custom Docker image: [docker/caddy/](docker/caddy/)

4. **Caddy Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
   - Instance name: `caddy01`
   - Image: `ghcr.io/accuser/atlas/caddy:latest` (published from [docker/caddy/](docker/caddy/))
   - Resource limits: 2 CPUs, 1GB memory (configurable)
   - Triple network interfaces:
     - `eth0`: Connected to "production" network (public-facing apps)
     - `eth1`: Connected to "management" network (internal services like Grafana)
     - `eth2`: Connected to "incusbr0" bridge (external access)
   - Caddyfile dynamically generated from module outputs

5. **Grafana Module** ([terraform/modules/grafana/](terraform/modules/grafana/))
   - Visualization and dashboarding platform
   - Persistent storage for dashboards and configuration (10GB)
   - Environment variable support for configuration
   - Generates Caddy reverse proxy configuration block
   - Domain-based access with IP restrictions
   - Rate limiting support (configurable requests/window)
   - Custom Docker image: [docker/grafana/](docker/grafana/)

6. **Grafana Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
   - Instance name: `grafana01`
   - Image: `ghcr.io/accuser/atlas/grafana:latest` (published from [docker/grafana/](docker/grafana/))
   - Domain: `grafana.accuser.dev` (publicly accessible via Caddy)
   - Resource limits: 2 CPUs, 1GB memory
   - Storage: 10GB persistent volume for `/var/lib/grafana`
   - Network: Connected to management network

7. **Loki Module** ([terraform/modules/loki/](terraform/modules/loki/))
   - Log aggregation system (internal only)
   - Persistent storage for log data (50GB)
   - Configurable retention (default: 30 days / 720h)
   - No public-facing reverse proxy configuration
   - Internal endpoint for Grafana data source
   - Custom Docker image: [docker/loki/](docker/loki/)

8. **Loki Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
   - Instance name: `loki01`
   - Image: `ghcr.io/accuser/atlas/loki:latest` (published from [docker/loki/](docker/loki/))
   - Internal endpoint: `http://loki01.incus:3100`
   - Resource limits: 2 CPUs, 2GB memory
   - Storage: 50GB persistent volume for `/loki`
   - Retention: 30 days (720h) with 2h delete delay
   - Network: Connected to management network (internal only)

9. **Prometheus Module** ([terraform/modules/prometheus/](terraform/modules/prometheus/))
   - Metrics collection and time-series database (internal only)
   - Persistent storage for metrics data (100GB)
   - Configurable retention (time-based and size-based)
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
    - Retention: 30 days (time-based), no size limit by default
    - Network: Connected to management network (internal only)

11. **step-ca Module** ([terraform/modules/step-ca/](terraform/modules/step-ca/))
    - Internal ACME Certificate Authority for TLS certificates
    - Persistent storage for CA data and certificates (1GB)
    - Configurable CA name and DNS names
    - ACME endpoint for automated certificate issuance
    - Internal endpoint for services requesting certificates
    - Custom Docker image: [docker/step-ca/](docker/step-ca/)

12. **step-ca Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `step-ca01`
    - Image: `ghcr.io/accuser/atlas/step-ca:latest` (published from [docker/step-ca/](docker/step-ca/))
    - CA name: "Atlas Internal CA"
    - DNS names: `step-ca01.incus,step-ca01,localhost`
    - ACME endpoint: `https://step-ca01.incus:9000`
    - Resource limits: 1 CPU, 512MB memory
    - Storage: 1GB persistent volume for `/home/step`
    - Network: Connected to management network (internal only)
    - CA fingerprint: Retrieved after deployment via `incus exec step-ca01 -- cat /home/step/fingerprint`

13. **Alertmanager Module** ([terraform/modules/alertmanager/](terraform/modules/alertmanager/))
    - Alert routing and notification management (internal only)
    - Persistent storage for silences and notification state (1GB)
    - Configurable notification routes (Slack, email, webhook)
    - Silencing and inhibition rules support
    - Integration with Prometheus via alertmanagers config
    - Custom Docker image: [docker/alertmanager/](docker/alertmanager/)

14. **Alertmanager Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `alertmanager01`
    - Image: `ghcr.io/accuser/atlas/alertmanager:latest` (published from [docker/alertmanager/](docker/alertmanager/))
    - Internal endpoint: `http://alertmanager01.incus:9093`
    - Resource limits: 1 CPU, 256MB memory
    - Storage: 1GB persistent volume for `/alertmanager`
    - Network: Connected to management network (internal only)
    - Prometheus integration: Configured via `alerting.alertmanagers` in prometheus.yml

15. **Mosquitto Module** ([terraform/modules/mosquitto/](terraform/modules/mosquitto/))
    - Eclipse Mosquitto MQTT broker for IoT messaging
    - External access via Incus proxy devices (new pattern for TCP services)
    - Persistent storage for retained messages and subscriptions
    - Optional TLS support via step-ca
    - Password file authentication support
    - Custom Docker image: [docker/mosquitto/](docker/mosquitto/)

16. **Mosquitto Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `mosquitto01`
    - Image: `ghcr.io/accuser/atlas/mosquitto:latest` (published from [docker/mosquitto/](docker/mosquitto/))
    - Internal endpoint: `mqtt://mosquitto01.incus:1883`
    - External access: Host ports 1883 (MQTT) and 8883 (MQTTS) via proxy devices
    - Resource limits: 1 CPU, 256MB memory
    - Storage: 5GB persistent volume for `/mosquitto/data`
    - Network: Connected to production network (externally accessible)

17. **Cloudflared Module** ([terraform/modules/cloudflared/](terraform/modules/cloudflared/))
    - Cloudflare Tunnel client for secure remote access via Zero Trust
    - Token-based authentication (managed via Cloudflare dashboard)
    - Metrics endpoint for Prometheus scraping
    - No persistent storage required (stateless)
    - Custom Docker image: [docker/cloudflared/](docker/cloudflared/)

18. **Cloudflared Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `cloudflared01`
    - Image: `ghcr.io/accuser/atlas/cloudflared:latest` (published from [docker/cloudflared/](docker/cloudflared/))
    - Metrics endpoint: `http://cloudflared01.incus:2000`
    - Resource limits: 1 CPU, 256MB memory
    - Network: Connected to management network (internal access to all services)
    - Conditionally deployed: Only created when `cloudflared_tunnel_token` is set

19. **Incus Metrics Module** ([terraform/modules/incus-metrics/](terraform/modules/incus-metrics/))
    - Generates mTLS certificates for scraping Incus container metrics
    - Uses Terraform TLS provider for certificate generation (ECDSA P-384)
    - Registers certificate with Incus as type "metrics"
    - Outputs certificate and private key for injection into Prometheus
    - No Docker image required (certificate management only)

20. **Incus Metrics** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Certificate name: `prometheus-metrics`
    - Metrics endpoint: `https://<management-gateway>:8443/1.0/metrics`
    - Certificate validity: 10 years (3650 days)
    - Conditionally deployed: Only created when `enable_incus_metrics` is true (default)
    - Provides container-level metrics: CPU, memory, disk, network, processes

21. **Incus Loki Module** ([terraform/modules/incus-loki/](terraform/modules/incus-loki/))
    - Configures native Incus logging to Loki (no Promtail required)
    - Pushes lifecycle events (instance start/stop, create, delete)
    - Pushes logging events (container and VM log output)
    - Uses Incus server-level configuration
    - No Docker image required (server configuration only)

22. **Incus Loki** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Logging name: `loki01`
    - Target address: `http://loki01.incus:3100`
    - Event types: `lifecycle,logging`
    - Conditionally deployed: Only created when `enable_incus_loki` is true (default)
    - Logs queryable in Grafana via Loki datasource

### External TCP Service Pattern (Proxy Devices)

For non-HTTP services that need external access (like MQTT), the project uses Incus proxy devices instead of Caddy reverse proxy:

```hcl
# In the module's profile definition
device {
  name = "mqtt-proxy"
  type = "proxy"
  properties = {
    listen  = "tcp:0.0.0.0:1883"      # Host listens on all interfaces
    connect = "tcp:127.0.0.1:1883"    # Forward to container
  }
}
```

**Benefits:**
- Native Incus feature, no additional containers
- Works for any TCP/UDP protocol
- Declarative in Terraform
- Direct port forwarding with minimal overhead

**Considerations:**
- Bypasses Caddy - no centralized HTTP logging for TCP traffic
- Port conflicts must be managed manually
- Each service manages its own TLS (via step-ca)

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
- Optional automatic snapshots via `enable_snapshots = true`

**Current storage volumes:**
- `grafana01-data` - 10GB - `/var/lib/grafana`
- `loki01-data` - 50GB - `/loki`
- `prometheus01-data` - 100GB - `/prometheus`
- `step-ca01-data` - 1GB - `/home/step`
- `alertmanager01-data` - 1GB - `/alertmanager`
- `mosquitto01-data` - 5GB - `/mosquitto/data`

### Retention Configuration

Both Prometheus and Loki support configurable retention policies to prevent storage volumes from filling up.

**Prometheus Retention:**
- Configured via environment variables: `RETENTION_TIME`, `RETENTION_SIZE`
- Time-based retention (default: 30 days): `retention_time = "30d"`
- Size-based retention (optional): `retention_size = "90GB"`
- Both can be used together; whichever triggers first will delete old data

```hcl
module "prometheus01" {
  # ...
  retention_time = "30d"    # Keep data for 30 days
  retention_size = "90GB"   # Or delete when storage exceeds 90GB
}
```

**Loki Retention:**
- Configured via environment variables: `RETENTION_PERIOD`, `RETENTION_DELETE_DELAY`
- Uses hours format (default: 720h = 30 days): `retention_period = "720h"`
- Delete delay (minimum 2h for safety): `retention_delete_delay = "2h"`
- Requires compactor to be enabled (automatically configured)

```hcl
module "loki01" {
  # ...
  retention_period       = "720h"  # Keep logs for 30 days
  retention_delete_delay = "2h"    # Wait 2h before deleting
}
```

**Common retention periods:**
| Duration | Prometheus | Loki |
|----------|------------|------|
| 7 days   | `7d`       | `168h` |
| 14 days  | `14d`      | `336h` |
| 30 days  | `30d`      | `720h` |
| 90 days  | `90d`      | `2160h` |

### Snapshot Scheduling

All modules with persistent storage support automatic snapshots via Incus native scheduling. Snapshots are disabled by default.

**Enabling snapshots:**

```hcl
module "grafana01" {
  # ... existing config ...

  enable_snapshots   = true
  snapshot_schedule  = "@daily"    # or cron: "0 2 * * *"
  snapshot_expiry    = "7d"        # Keep for 7 days
  snapshot_pattern   = "auto-{{creation_date}}"
}
```

**Default schedules by service:**

| Service | Default Schedule | Default Retention |
|---------|-----------------|-------------------|
| Grafana | @daily | 7d |
| Alertmanager | @daily | 7d |
| Mosquitto | @daily | 7d |
| Prometheus | @weekly | 2w |
| Loki | @weekly | 2w |
| step-ca | @weekly | 4w |

See [BACKUP.md](BACKUP.md) for detailed backup procedures and disaster recovery playbooks.

### TLS Configuration

The project includes an internal ACME Certificate Authority (step-ca) for automated TLS certificate management. Services can request certificates from step-ca to enable encrypted communication.

#### How TLS Works

1. **step-ca initializes** - On first start, step-ca generates a root CA certificate and fingerprint
2. **Services bootstrap trust** - Services use the CA fingerprint to establish trust
3. **Certificate request** - Services request certificates via ACME protocol
4. **Automatic renewal** - Certificates are short-lived (24h default) and renewed automatically

#### Enabling TLS for Services

**Step 1: Deploy step-ca and retrieve the fingerprint**

After deploying with `make deploy`, retrieve the CA fingerprint:

```bash
# Get the fingerprint (also shown in tofu output)
incus exec step-ca01 -- cat /home/step/fingerprint

# Or view the command from Terraform output
cd terraform && tofu output step_ca_fingerprint_command
```

**Step 2: Enable TLS in service modules**

Update `terraform/main.tf` to enable TLS for a service:

```hcl
module "grafana01" {
  source = "./modules/grafana"

  # ... existing configuration ...

  # Enable TLS
  enable_tls         = true
  stepca_url         = "https://step-ca01.incus:9000"
  stepca_fingerprint = "abc123..."  # From step 1
}
```

**Step 3: Re-deploy**

```bash
make deploy
```

#### TLS-Enabled Services

The following services support TLS via step-ca:

| Service | TLS Variable | Default Port (TLS) |
|---------|--------------|-------------------|
| Grafana | `enable_tls` | 3000 (HTTPS) |
| Prometheus | `enable_tls` | 9090 (HTTPS) |
| Loki | `enable_tls` | 3100 (HTTPS) |

#### Certificate Lifecycle

- **Duration**: 24 hours (configurable via `cert_duration`)
- **Renewal**: Automatic via entrypoint scripts on container restart
- **Storage**: Certificates stored in `/etc/<service>/tls/` inside containers
- **Root CA**: Available at `/home/step/certs/root_ca.crt` in step-ca container

#### Two-Phase Deployment for TLS

Since the CA fingerprint is generated at runtime, TLS requires a two-phase deployment:

```bash
# Phase 1: Deploy infrastructure (step-ca generates fingerprint)
make deploy

# Get the fingerprint
FINGERPRINT=$(incus exec step-ca01 -- cat /home/step/fingerprint)
echo "CA Fingerprint: $FINGERPRINT"

# Phase 2: Update terraform.tfvars or main.tf with fingerprint, re-deploy
# Edit main.tf to add enable_tls = true and stepca_fingerprint = "..."
make deploy
```

#### Troubleshooting TLS

**Check if step-ca is healthy:**
```bash
incus exec step-ca01 -- step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt
```

**View CA certificate details:**
```bash
incus exec step-ca01 -- step certificate inspect /home/step/certs/root_ca.crt
```

**Test certificate request manually:**
```bash
incus exec step-ca01 -- step ca certificate test.local /tmp/test.crt /tmp/test.key \
  --provisioner acme \
  --ca-url https://localhost:9000
```

### Profile Architecture

Each service uses Incus profiles to define resource limits, devices, and configuration. The project follows a **standardized profile composition strategy** across all modules.

#### Profile Composition Pattern

All containers use a two-profile composition:
```hcl
profiles = ["default", incus_profile.service.name]
```

**"default" profile**: Incus's built-in profile providing baseline container configuration
- Root filesystem device
- Basic network device (eth0)
- Standard container settings

**Service-specific profile**: Module-defined profile that extends/overrides defaults
- Resource limits (CPU, memory)
- Service-specific devices (storage volumes, additional NICs)
- Boot and restart policies

Profiles are applied in order, so service-specific settings take precedence over defaults.

#### Profile Structure

Every module follows the same pattern for profile definition in `main.tf`:

```hcl
resource "incus_profile" "service" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit      # Configurable CPU cores
    "limits.memory"         = var.memory_limit   # Configurable RAM
    "limits.memory.enforce" = "hard"             # Strict memory enforcement
    "boot.autorestart"      = "true"             # Auto-restart on host reboot
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool  # Default: "local"
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.network_name
    }
  }

  # Optional: Additional devices (storage volumes, extra NICs)
}
```

#### Resource Limits

All services enforce hard memory limits and configurable resources:

| Service | CPU (Default) | Memory (Default) | Validation |
|---------|---------------|-----------------|------------|
| Caddy   | 2 cores       | 1GB             | 1-64 CPUs, MB/GB format |
| Grafana | 2 cores       | 1GB             | 1-64 CPUs, MB/GB format |
| Loki    | 2 cores       | 2GB             | 1-64 CPUs, MB/GB format |
| Prometheus | 2 cores    | 2GB             | 1-64 CPUs, MB/GB format |
| step-ca | 1 core        | 512MB           | 1-64 CPUs, MB/GB format |
| Alertmanager | 1 core   | 256MB           | 1-64 CPUs, MB/GB format |
| Mosquitto | 1 core      | 256MB           | 1-64 CPUs, MB/GB format |

All limits are validated at the Terraform variable level to ensure correctness before deployment.

#### Profile Naming Convention

Profiles follow a simple, service-specific naming pattern:

| Service | Profile Name | Instance Name |
|---------|--------------|---------------|
| Caddy   | `caddy`      | `caddy01`     |
| Grafana | `grafana`    | `grafana01`   |
| Loki    | `loki`       | `loki01`      |
| Prometheus | `prometheus` | `prometheus01` |
| step-ca | `step-ca`    | `step-ca01`   |
| Alertmanager | `alertmanager` | `alertmanager01` |
| Mosquitto | `mosquitto` | `mosquitto01` |

Profile names are independent of instance names, allowing flexibility for multiple instances.

#### Dynamic Device Management

Profiles use Terraform's `dynamic` blocks for conditional device attachment:

```hcl
dynamic "device" {
  for_each = var.enable_data_persistence ? [1] : []
  content {
    name = "service-data"
    type = "disk"
    properties = {
      source = incus_storage_volume.service_data[0].name
      pool   = var.storage_pool
      path   = "/var/lib/service"
    }
  }
}
```

This enables:
- Optional persistent storage (enabled/disabled per instance)
- Clean profiles when persistence is disabled
- Single definition handling both scenarios

#### Network Device Configuration

**Standard services** (Grafana, Loki, Prometheus, step-ca):
- Single network interface (`eth0`)
- Connected to management network by default
- Internal-only communication

**Caddy** (special case - reverse proxy):
- Three network interfaces:
  - `eth0`: Production network (public-facing apps)
  - `eth1`: Management network (internal services)
  - `eth2`: External network (incusbr0 bridge for internet access)

#### Profile Dependencies

Profiles have explicit dependencies on storage volumes when persistence is enabled:

```hcl
resource "incus_profile" "service" {
  # ... profile config

  depends_on = [
    incus_storage_volume.service_data
  ]
}
```

This ensures:
- Storage volumes exist before profiles reference them
- Proper creation order during `tofu apply`
- Clean teardown order during `tofu destroy`

#### Why Use the Default Profile?

The "default" profile provides:
- Standard root filesystem device configuration
- Basic network device setup
- Common container settings and limits
- Proven baseline used by Incus community

By composing with "default" rather than replacing it:
- Leverage Incus best practices
- Reduce duplication in module profiles
- Service profiles focus only on service-specific requirements
- Easier to maintain as Incus evolves

**Verification**: To see the default profile contents on your Incus server:
```bash
incus profile show default
```

#### Profile Design Principles

1. **Consistency**: All modules follow identical profile patterns
2. **Modularity**: Profiles are self-contained within modules
3. **Flexibility**: Variable-driven configuration for all limits
4. **Composition**: Extend "default" rather than replace
5. **Separation of Concerns**: Profiles handle resources, instances handle runtime config

This approach enables easy scaling - new instances reuse the proven profile pattern with customized resource limits.

### Adding New Service Modules

**For public-facing services (with Caddy reverse proxy):**

1. Create Docker image in `docker/yourservice/` with Dockerfile
2. Add service to GitHub Actions matrix in `.github/workflows/release.yml`
3. Create Terraform module in `terraform/modules/yourservice/`
4. Add `domain`, `allowed_ip_range`, and port variables to module
5. Set default image to `ghcr:accuser/atlas/yourservice:latest`
6. Create `templates/caddyfile.tftpl` for reverse proxy config
7. Add `caddy_config_block` output using templatefile()
8. Instantiate module in [terraform/main.tf](terraform/main.tf)
9. Add module's `caddy_config_block` to Caddy's `service_blocks` list
10. Push to GitHub to build and publish image

**For internal-only services (no public access):**

1. Create Docker image in `docker/yourservice/` with Dockerfile
2. Add service to GitHub Actions matrix in `.github/workflows/release.yml`
3. Create Terraform module in `terraform/modules/yourservice/`
4. Set default image to `ghcr:accuser/atlas/yourservice:latest`
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

  network_name = incus_network.management.name

  domain           = "grafana-dev.accuser.dev"
  allowed_ip_range = "192.168.68.0/22"  # Required: Set to your network CIDR

  # Uses ghcr.io image by default (ghcr:accuser/atlas/grafana:latest)
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
- Five managed networks: development (10.10.0.1/24), testing (10.20.0.1/24), staging (10.30.0.1/24), production (10.40.0.1/24), management (10.50.0.1/24)
- Optional IPv6 dual-stack support using ULA addresses (fd00:10:XX::1/64)
- Application environments: development, testing, staging, production
- Management network: hosts internal services (monitoring stack: Grafana, Loki, Prometheus)
- Services on same network can communicate via internal DNS
- Public services exposed via Caddy reverse proxy with triple NICs (production, management, external)
- IP-based access control for security
- Automatic HTTPS via Let's Encrypt with Cloudflare DNS validation

**IPv6 Configuration:**
- IPv6 is disabled by default (set to empty string)
- Enable by setting `*_network_ipv6` variables in terraform.tfvars
- Uses ULA (Unique Local Address) prefix fd00::/8 for private addressing
- NAT66 configurable per-network via `*_network_ipv6_nat` variables
- Example: `production_network_ipv6 = "fd00:10:40::1/64"`

**Rate Limiting:**
- Built-in rate limiting via mholt/caddy-ratelimit plugin
- Default limits: 100 requests/min for general endpoints, 10 requests/min for login endpoints
- Sliding window algorithm for smooth rate limiting
- Per-service zones prevent cross-service interference
- Configurable via Terraform variables (`enable_rate_limiting`, `rate_limit_requests`, etc.)
- Protects against brute force attacks, DoS attempts, and resource exhaustion

**Storage Management:**
- Each service module manages its own storage volume
- Conditionally created based on `enable_data_persistence`
- Configurable size per instance
- Proper lifecycle management by Terraform

### Monitoring Stack Integration

The complete observability stack is designed to work together with automatic configuration:

1. **Grafana** (public) - Visualization frontend
   - Access: `https://grafana.accuser.dev`
   - Auto-configured datasources for Prometheus and Loki
   - Datasources provisioned via Terraform on deployment

2. **Prometheus** (internal) - Metrics storage and health monitoring
   - Endpoint: `http://prometheus01.incus:9090`
   - Scrapes metrics from all services (Grafana, Loki, Caddy, step-ca, self)
   - Health check monitoring for infrastructure components
   - Queried by Grafana for metric visualization
   - Scrape interval: 15 seconds

3. **Loki** (internal) - Log aggregation
   - Endpoint: `http://loki01.incus:3100`
   - Receives logs from applications
   - Queried by Grafana for log exploration

**Automatic Configuration:**

Datasources are automatically provisioned in Grafana via Terraform:
```hcl
datasources = [
  {
    name            = "Prometheus"
    type            = "prometheus"
    url             = "http://prometheus01.incus:9090"
    is_default      = true
    tls_skip_verify = false
  },
  {
    name            = "Loki"
    type            = "loki"
    url             = "http://loki01.incus:3100"
    is_default      = false
    tls_skip_verify = false
  }
]
```

**Health Check Monitoring:**

Prometheus is configured to scrape health and metrics endpoints from all services:
- `grafana01.incus:3000` - Grafana metrics
- `loki01.incus:3100` - Loki metrics
- `caddy01.incus:2019` - Caddy admin API metrics
- `step-ca01.incus:9000` - step-ca health endpoint
- `node-exporter01.incus:9100` - Host system metrics (CPU, memory, disk, network)
- `<management-gateway>:8443` - Incus container metrics (mTLS authenticated)
- `localhost:9090` - Prometheus self-monitoring

All Docker containers include built-in health checks that run every 30 seconds:
- Caddy: `caddy version` command
- Grafana: HTTP check on `/api/health`
- Loki: HTTP check on `/ready`
- Prometheus: HTTP check on `/-/ready`
- step-ca: `step ca health` command
- Node Exporter: HTTP check on `/metrics`

These health checks are monitored by Docker and can be viewed with `incus exec <container> -- docker ps`.

**Infrastructure Monitoring:**

4. **Node Exporter** (internal) - Host-level metrics collection
   - Endpoint: `http://node-exporter01.incus:9100`
   - Collects host system metrics:
     - CPU usage and load averages
     - Memory usage and swap
     - Disk I/O and filesystem usage
     - Network traffic and errors
     - System uptime
   - Mounted host paths: `/`, `/proc`, `/sys` (read-only)
   - Scraped by Prometheus every 15 seconds

5. **Incus Metrics** (internal) - Container-level metrics from Incus API
   - Endpoint: `https://<management-gateway>:8443/1.0/metrics`
   - Requires mTLS authentication (certificate type: `metrics`)
   - Collects per-container metrics:
     - `incus_cpu_seconds_total` - Container CPU usage
     - `incus_cpu_effective_total` - Effective CPU count
     - `incus_memory_*` - Memory usage statistics
     - `incus_disk_*` - Disk I/O counters
     - `incus_network_*` - Network traffic per interface
     - `incus_procs_total` - Process count per container
   - Certificate auto-generated by Terraform TLS provider
   - Scraped by Prometheus every 15 seconds
   - Metrics cached by Incus for 8 seconds

**Alerting and Rules:**

Prometheus is configured with comprehensive alerting rules for infrastructure monitoring:
- Rule evaluation interval: 15 seconds
- Alert rules file: `terraform/prometheus-alerts.yml`
- Automatically injected into Prometheus on deployment
- Alertmanager integration ready (configure targets as needed)

**Active Alert Rules:**

*Service Availability:*
- `ServiceDown` - Critical alert when a service is unreachable for >2 minutes
- `ServiceFlapping` - Warning when a service restarts >5 times in 10 minutes

*Memory Alerts:*
- `HighMemoryUsage` - Warning at >80% container memory usage for >5 minutes
- `CriticalMemoryUsage` - Critical at >95% container memory (OOM kill imminent)
- `HostOutOfMemory` - Warning when host has <10% memory available
- `HostHighMemoryPressure` - Warning on excessive page faults

*Disk Space Alerts:*
- `DiskSpaceWarning` - Warning at <20% disk space remaining
- `DiskSpaceCritical` - Critical at <10% disk space remaining

*CPU and Load:*
- `HighCPUUsage` - Warning at >80% CPU usage for >10 minutes
- `HighLoadAverage` - Warning when load average exceeds 2x CPU count

All alerts include detailed annotations with current values and context.

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
   make init
   make plan
   make apply
   ```

4. **Verify**:
   ```bash
   cd terraform && tofu output
   ```

### Docker Image Configuration

**Default: GitHub Container Registry Images**

All modules are configured to use custom images published to GitHub Container Registry:
- Caddy: `ghcr:accuser/atlas/caddy:latest`
- Grafana: `ghcr:accuser/atlas/grafana:latest`
- Loki: `ghcr:accuser/atlas/loki:latest`
- Prometheus: `ghcr:accuser/atlas/prometheus:latest`

These images are:
- Built automatically by the Release workflow on push to main
- Published to GitHub Container Registry (ghcr.io)
- Extended from official images with custom plugins and configuration
- Publicly accessible (no authentication required)

**Image Reference Format (ghcr: vs ghcr.io/)**

Terraform modules use `ghcr:` prefix (e.g., `ghcr:accuser/atlas/grafana:latest`) which references an **Incus remote** named "ghcr" that points to `https://ghcr.io`. This is not a typo - it's Incus-specific syntax.

The bootstrap process (`make bootstrap`) automatically configures these OCI remotes:
- `ghcr` → `https://ghcr.io` (GitHub Container Registry)
- `docker` → `https://docker.io` (Docker Hub)

You can verify remotes are configured with:
```bash
incus remote list
```

To manually add a remote (if not using bootstrap):
```bash
incus remote add ghcr https://ghcr.io --protocol=oci --public
```

**CI/CD Pipeline:**

The pipeline is split into two workflows:
- `ci.yml` - Validation and testing (feature branches, PRs)
- `release.yml` - Build and publish (main branch only)

**Image Publishing Workflow:**

1. Edit Dockerfile in `docker/*/Dockerfile`
2. Create feature branch and push changes
3. CI workflow validates and tests the image
4. Open PR to `main` - CI runs full validation
5. Merge PR - Release workflow builds and publishes to ghcr.io
6. Terraform pulls latest image on next apply

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
- Images are automatically built and published by the Release workflow on push to main
- Access to services requires explicit `allowed_ip_range` configuration (no default for security)
- All services use the `production` network for connectivity
- Storage volumes use the `local` storage pool and are created automatically when modules are applied
- Each module has a `versions.tf` specifying the Incus provider requirement
- Images must be public in GitHub Container Registry for Incus to pull without authentication

## Outputs

After applying, use `cd terraform && tofu output` to view:
- `grafana_caddy_config` - Generated Caddy configuration for Grafana
- `loki_endpoint` - Internal Loki endpoint URL
- `prometheus_endpoint` - Internal Prometheus endpoint URL
- `step_ca_acme_endpoint` - step-ca ACME endpoint URL for certificate requests
- `step_ca_acme_directory` - step-ca ACME directory URL for ACME clients
- `step_ca_fingerprint_command` - Command to retrieve CA fingerprint for TLS configuration
- `alertmanager_endpoint` - Internal Alertmanager endpoint URL for alert routing
- `mosquitto_mqtt_endpoint` - Internal MQTT endpoint URL
- `mosquitto_external_ports` - External host ports for MQTT access (1883, 8883)
- `cloudflared_metrics_endpoint` - Cloudflared metrics endpoint (if enabled)
- `cloudflared_instance_status` - Cloudflared instance status (if enabled)
- `incus_metrics_endpoint` - Incus metrics endpoint URL being scraped by Prometheus
- `incus_metrics_certificate_fingerprint` - Fingerprint of the metrics certificate registered with Incus
- `incus_loki_logging_name` - Name of the Incus logging configuration for Loki
- `incus_loki_address` - Loki address configured for Incus logging
