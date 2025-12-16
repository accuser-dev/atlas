# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform infrastructure project that manages Incus containers for a complete monitoring stack including Grafana, Prometheus, and Loki. External access is provided via Cloudflare Tunnel. The setup provisions containerized services with persistent storage and dynamic configuration generation.

The project is organized into two main directories:
- **`docker/`** - Custom Docker images for each service
- **`terraform/`** - Infrastructure as Code using Terraform

## Resource Requirements

### Compute Resources

| Service | CPU (cores) | Memory | Purpose |
|---------|-------------|--------|---------|
| Grafana | 2 | 1GB | Dashboards, visualization |
| Prometheus | 2 | 2GB | Metrics storage |
| Loki | 2 | 2GB | Log aggregation |
| Alertmanager | 1 | 256MB | Alert routing |
| step-ca | 1 | 512MB | Certificate authority |
| Node Exporter | 1 | 128MB | Host metrics |
| Mosquitto | 1 | 256MB | MQTT broker |
| CoreDNS | 1 | 128MB | Split-horizon DNS |
| Cloudflared | 1 | 256MB | Tunnel client (optional) |
| Atlantis | 2 | 1GB | GitOps controller (optional) |
| **Total** | **11-14** | **6.5-7.5GB** | |

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
| atlantis01-data | 10GB | Minimal | Plans cache, locks (optional) |
| **Total** | **167-177GB** | | |

*Growth rates vary significantly based on workload. Adjust retention settings to control storage usage.

### Network Requirements

| Network | CIDR | Type | Purpose |
|---------|------|------|---------|
| production | 10.10.0.0/24 | bridge/physical | Public-facing services (Mosquitto) |
| management | 10.20.0.0/24 | bridge | Internal services (monitoring stack) |
| gitops | 10.30.0.0/24 | bridge | GitOps automation (optional, Atlantis) |

**Network Modes:**

The production network supports two deployment modes:

| Mode | Use Case | External Access |
|------|----------|-----------------|
| **bridge** (default) | Standard deployments | Via proxy devices on host ports |
| **physical** | IncusOS clusters | Direct LAN IPs via DHCP/static |

*Bridge mode:* Production network is NAT'd. Services like Mosquitto are exposed via Incus proxy devices that listen on host ports.

*Physical mode:* Production network attaches directly to a physical LAN interface. Containers get LAN IPs directly - no proxy devices needed.

**External Access:**
- Cloudflared: Outbound only (no inbound ports) - provides external access to Grafana, Atlantis via Cloudflare Tunnel
- Mosquitto: Ports 1883, 8883 (MQTT/MQTTS) - via proxy devices in bridge mode, direct in physical mode
- CoreDNS: Port 53 (UDP/TCP) - via proxy devices in bridge mode, direct in physical mode

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
├── docker/                    # Custom Docker images (Atlantis only - other services use system containers)
│   └── atlantis/             # Atlantis GitOps controller
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
│   │   ├── alertmanager/
│   │   ├── atlantis/
│   │   ├── cloudflared/
│   │   ├── coredns/
│   │   ├── grafana/
│   │   ├── incus-loki/
│   │   ├── incus-metrics/
│   │   ├── loki/
│   │   ├── mosquitto/
│   │   ├── node-exporter/
│   │   ├── prometheus/
│   │   └── step-ca/
│   ├── init.sh               # Initialization wrapper script
│   ├── main.tf               # Module instantiations
│   ├── variables.tf          # Variable definitions
│   ├── locals.tf             # Centralized service configuration
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
make build-atlantis

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

**Note:** Production images are built and published automatically via GitHub Actions to `ghcr.io/accuser-dev/atlas/*:latest`. Local builds are only needed for development/testing.

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

Only Atlantis uses an OCI container image. Other services use Alpine Linux system containers with cloud-init.

Images are automatically built and published by GitHub Actions when code is pushed to the `main` branch:
- Atlantis: `ghcr.io/accuser-dev/atlas/atlantis:latest`

**Local Development:**
```bash
# Build Atlantis image locally for testing
make build-atlantis
IMAGE_TAG=v1.0.0 make build-atlantis
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
- [terraform/locals.tf](terraform/locals.tf) - Centralized service configuration
- [terraform/outputs.tf](terraform/outputs.tf) - Output values (endpoints, configurations)
- [terraform/terraform.tfvars](terraform/terraform.tfvars) - Variable values (gitignored, contains secrets)

**Terraform Modules:**
- [terraform/modules/grafana/](terraform/modules/grafana/) - Grafana observability platform
  - [main.tf](terraform/modules/grafana/main.tf) - Profile, container, and storage volume
  - [variables.tf](terraform/modules/grafana/variables.tf) - Module input variables including domain config
  - [outputs.tf](terraform/modules/grafana/outputs.tf) - Module outputs
  - [templates/cloud-init.yaml.tftpl](terraform/modules/grafana/templates/cloud-init.yaml.tftpl) - Cloud-init configuration
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
- [docker/atlantis/](docker/atlantis/) - Custom Atlantis image with OpenTofu support
  - [Dockerfile](docker/atlantis/Dockerfile) - Image build definition
  - [README.md](docker/atlantis/README.md) - GitOps configuration instructions

### Infrastructure Components

1. **Incus Provider** ([terraform/providers.tf](terraform/providers.tf), [terraform/versions.tf](terraform/versions.tf))
   - Uses the `lxc/incus` provider (v1.0.0+)
   - Manages LXC/Incus containers and storage volumes

2. **Network Configuration** ([terraform/modules/base-infrastructure/](terraform/modules/base-infrastructure/))
   - Two managed networks: production (10.10.0.0/24), management (10.20.0.0/24)
   - Optional gitops network (10.30.0.0/24) when `enable_gitops = true`
   - Optional IPv6 support (dual-stack) using ULA addresses (e.g., fd00:10:10::1/64)
   - NAT enabled for external connectivity (configurable for both IPv4 and IPv6)
   - Management network hosts internal services (monitoring stack)

3. **Grafana Module** ([terraform/modules/grafana/](terraform/modules/grafana/))
   - Visualization and dashboarding platform
   - Uses Alpine Linux system container with cloud-init
   - Persistent storage for dashboards and configuration (10GB)
   - Admin credentials configured via Terraform variables
   - Domain configuration for Cloudflare Tunnel access
   - Datasources and dashboards provisioned via cloud-init

4. **Grafana Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
   - Instance name: `grafana01`
   - Image: `images:alpine/3.21/cloud` (system container)
   - Domain: `grafana.accuser.dev` (accessible via Cloudflare Tunnel)
   - Resource limits: 2 CPUs, 1GB memory
   - Storage: 10GB persistent volume for `/var/lib/grafana`
   - Network: Connected to management network

5. **Loki Module** ([terraform/modules/loki/](terraform/modules/loki/))
   - Log aggregation system (internal only)
   - Uses Alpine Linux system container with cloud-init (no Docker image)
   - Persistent storage for log data (50GB)
   - Configurable retention (default: 30 days / 720h)
   - No public-facing reverse proxy configuration
   - Internal endpoint for Grafana data source

8. **Loki Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
   - Instance name: `loki01`
   - Image: `images:alpine/3.21/cloud` (system container)
   - Internal endpoint: `http://loki01.incus:3100`
   - Resource limits: 2 CPUs, 2GB memory
   - Storage: 50GB persistent volume for `/loki`
   - Retention: 30 days (720h) with 2h delete delay
   - Network: Connected to management network (internal only)

9. **Prometheus Module** ([terraform/modules/prometheus/](terraform/modules/prometheus/))
   - Metrics collection and time-series database (internal only)
   - Uses Alpine Linux system container with cloud-init (no Docker image)
   - Persistent storage for metrics data (100GB)
   - Configurable retention (time-based and size-based)
   - prometheus.yml configuration via Terraform variable
   - No public-facing reverse proxy configuration
   - Internal endpoint for Grafana data source

10. **Prometheus Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `prometheus01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Internal endpoint: `http://prometheus01.incus:9090`
    - Resource limits: 2 CPUs, 2GB memory
    - Storage: 100GB persistent volume for `/prometheus`
    - Retention: 30 days (time-based), no size limit by default
    - Network: Connected to management network (internal only)

11. **step-ca Module** ([terraform/modules/step-ca/](terraform/modules/step-ca/))
    - Internal ACME Certificate Authority for TLS certificates
    - Uses Alpine Linux system container with cloud-init (no Docker image)
    - Persistent storage for CA data and certificates (1GB)
    - Configurable CA name and DNS names
    - ACME endpoint for automated certificate issuance
    - Internal endpoint for services requesting certificates

12. **step-ca Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `step-ca01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - CA name: "Atlas Internal CA"
    - DNS names: `step-ca01.incus,step-ca01,localhost`
    - ACME endpoint: `https://step-ca01.incus:9000`
    - Resource limits: 1 CPU, 512MB memory
    - Storage: 1GB persistent volume for `/home/step`
    - Network: Connected to management network (internal only)
    - CA fingerprint: Retrieved after deployment via `incus exec step-ca01 -- cat /home/step/fingerprint`

13. **Alertmanager Module** ([terraform/modules/alertmanager/](terraform/modules/alertmanager/))
    - Alert routing and notification management (internal only)
    - Uses Alpine Linux system container with cloud-init (no Docker image)
    - Persistent storage for silences and notification state (1GB)
    - Configurable notification routes (Slack, email, webhook)
    - Silencing and inhibition rules support
    - Integration with Prometheus via alertmanagers config

14. **Alertmanager Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `alertmanager01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Internal endpoint: `http://alertmanager01.incus:9093`
    - Resource limits: 1 CPU, 256MB memory
    - Storage: 1GB persistent volume for `/var/lib/alertmanager`
    - Network: Connected to management network (internal only)
    - Prometheus integration: Configured via `alerting.alertmanagers` in prometheus.yml

15. **Mosquitto Module** ([terraform/modules/mosquitto/](terraform/modules/mosquitto/))
    - Eclipse Mosquitto MQTT broker for IoT messaging
    - Uses Alpine Linux system container with cloud-init (no Docker image)
    - External access via Incus proxy devices (pattern for TCP services)
    - Persistent storage for retained messages and subscriptions
    - Optional TLS support via step-ca
    - Password file authentication support

16. **Mosquitto Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `mosquitto01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Internal endpoint: `mqtt://mosquitto01.incus:1883`
    - External access: Host ports 1883 (MQTT) and 8883 (MQTTS) via proxy devices
    - Resource limits: 1 CPU, 256MB memory
    - Storage: 5GB persistent volume for `/mosquitto/data`
    - Network: Connected to production network (externally accessible)

17. **CoreDNS Module** ([terraform/modules/coredns/](terraform/modules/coredns/))
    - Split-horizon DNS server for internal service resolution
    - Uses Alpine Linux system container with cloud-init (no Docker image)
    - Authoritative for internal zone (e.g., `accuser.dev`)
    - Forwards `.incus` queries to Incus DNS resolver
    - Forwards external queries to upstream DNS (Cloudflare, Google)
    - External access via Incus proxy devices (UDP+TCP on port 53)
    - Zone file generated from Terraform service module outputs

18. **CoreDNS Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `coredns01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Internal endpoint: `coredns01.incus:53`
    - External access: Host port 53 (UDP+TCP) via proxy devices (bridge mode)
    - Resource limits: 1 CPU, 128MB memory
    - Network: Connected to production network (LAN accessible)
    - Health endpoint: `http://coredns01.incus:8080/health`
    - Metrics endpoint: `http://coredns01.incus:9153/metrics`

19. **Cloudflared Module** ([terraform/modules/cloudflared/](terraform/modules/cloudflared/))
    - Cloudflare Tunnel client for secure remote access via Zero Trust
    - Uses Alpine Linux system container with cloud-init (no Docker image)
    - Token-based authentication (managed via Cloudflare dashboard)
    - Metrics endpoint for Prometheus scraping
    - No persistent storage required (stateless)

20. **Cloudflared Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `cloudflared01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Metrics endpoint: `http://cloudflared01.incus:2000`
    - Resource limits: 1 CPU, 256MB memory
    - Network: Connected to management network (internal access to all services)
    - Conditionally deployed: Only created when `cloudflared_tunnel_token` is set

21. **Incus Metrics Module** ([terraform/modules/incus-metrics/](terraform/modules/incus-metrics/))
    - Generates mTLS certificates for scraping Incus container metrics
    - Uses Terraform TLS provider for certificate generation (ECDSA P-384)
    - Registers certificate with Incus as type "metrics"
    - Outputs certificate and private key for injection into Prometheus
    - No Docker image required (certificate management only)

22. **Incus Metrics** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Certificate name: `prometheus-metrics`
    - Metrics endpoint: `https://<management-gateway>:8443/1.0/metrics`
    - Certificate validity: 10 years (3650 days)
    - Conditionally deployed: Only created when `enable_incus_metrics` is true (default)
    - Provides container-level metrics: CPU, memory, disk, network, processes

23. **Incus Loki Module** ([terraform/modules/incus-loki/](terraform/modules/incus-loki/))
    - Configures native Incus logging to Loki (no Promtail required)
    - Pushes lifecycle events (instance start/stop, create, delete)
    - Pushes logging events (container and VM log output)
    - Uses Incus server-level configuration
    - No Docker image required (server configuration only)

24. **Incus Loki** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Logging name: `loki01`
    - Target address: `http://loki01.incus:3100`
    - Event types: `lifecycle,logging`
    - Conditionally deployed: Only created when `enable_incus_loki` is true (default)
    - Logs queryable in Grafana via Loki datasource

25. **Atlantis Module** ([terraform/modules/atlantis/](terraform/modules/atlantis/))
    - GitOps controller for PR-based infrastructure management
    - Automatic `terraform plan` on PR creation/update
    - Apply changes via PR comment `atlantis apply`
    - Webhook endpoint proxied via dedicated Caddy GitOps instance (GitHub IP allowlisting, rate limiting)
    - Persistent storage for plans cache and locks (10GB)
    - Custom Docker image: [docker/atlantis/](docker/atlantis/)

26. **Atlantis Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `atlantis01`
    - Image: `ghcr.io/accuser-dev/atlas/atlantis:latest` (published from [docker/atlantis/](docker/atlantis/))
    - Webhook endpoint: `https://<atlantis_domain>/events`
    - Resource limits: 2 CPUs, 1GB memory
    - Storage: 10GB persistent volume for `/atlantis-data`
    - Network: Connected to gitops network (10.30.0.0/24)
    - Conditionally deployed: Only created when `enable_gitops` is true (default: false)
    - See [GITOPS.md](GITOPS.md) for setup and usage instructions

27. **Caddy GitOps Module** ([terraform/modules/caddy-gitops/](terraform/modules/caddy-gitops/))
    - Dedicated Caddy instance for GitOps network webhook traffic
    - Separate from main Caddy instance (one Caddy per network pattern)
    - GitHub IP allowlisting for webhook security
    - Rate limiting for webhook protection
    - Uses same custom Caddy image as main instance

28. **Caddy GitOps Instance** (instantiated in [terraform/main.tf](terraform/main.tf))
    - Instance name: `caddy-gitops01`
    - Image: `ghcr.io/accuser-dev/atlas/caddy:latest`
    - Resource limits: 1 CPU, 256MB memory
    - Network: Connected to gitops network + external (incusbr0)
    - Conditionally deployed: Only created when `enable_gitops` is true

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
- `atlantis01-data` - 10GB - `/atlantis-data` (optional, if Atlantis enabled)

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

The project includes an internal ACME Certificate Authority (step-ca) for automated TLS certificate management. External services (like Mosquitto) can request certificates from step-ca to enable encrypted communication.

#### How TLS Works

1. **step-ca initializes** - On first start, step-ca generates a root CA certificate and fingerprint
2. **Services bootstrap trust** - Services use the CA fingerprint to establish trust
3. **Certificate request** - Services request certificates via ACME protocol
4. **Automatic renewal** - Certificates are short-lived (24h default) and renewed automatically

#### step-ca Setup

After deploying with `make deploy`, retrieve the CA fingerprint:

```bash
# Get the fingerprint (also shown in tofu output)
incus exec step-ca01 -- cat /home/step/fingerprint

# Or view the command from Terraform output
cd terraform && tofu output step_ca_fingerprint_command
```

#### Certificate Lifecycle

- **Duration**: 24 hours (configurable via `cert_duration` variable)
- **Root CA**: Available at `/home/step/certs/root_ca.crt` in step-ca container
- **ACME endpoint**: `https://step-ca01.incus:9000`

#### Internal Service Communication

Internal services (Grafana, Prometheus, Loki) communicate over the management network using HTTP. TLS is not required for internal traffic as:
- The management network (10.20.0.0/24) is isolated
- Traffic does not traverse external networks
- Caddy terminates external TLS for public-facing services

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

All containers use profile composition **without the Incus default profile**. This provides explicit control over network access and avoids unwanted external connectivity.

**Standard services** (most containers):
```hcl
profiles = [
  module.base.container_base_profile.name,     # boot.autorestart only
  module.base.management_network_profile.name, # Management network NIC
]
# Service module's profile provides root disk with size limit
```

**Caddy** (reverse proxy - special case):
```hcl
profiles = [
  module.base.container_base_profile.name,  # boot.autorestart only
]
# Caddy module manages its own root disk and multi-network NICs
```

**Base profiles from base-infrastructure module:**
- `container_base_profile`: Provides only `boot.autorestart = true`
- `management_network_profile`: Provides eth0 NIC on management network (10.20.0.0/24)
- `production_network_profile`: Provides eth0 NIC on production network (10.10.0.0/24)
- `gitops_network_profile`: Provides eth0 NIC on gitops network (10.30.0.0/24, optional)

**Root disk management:**
- Each service module defines its own root disk device with a configurable size limit
- This prevents DoS via unlimited storage and provides per-service control
- Default sizes: 1GB for lightweight services, 2GB for heavier services (grafana, loki, prometheus, atlantis)

**Why NOT use the default profile:**
- Default profile provides eth0 on incusbr0 (external bridge) - gives unwanted external network access
- Network profiles provide appropriate isolated NICs
- Explicit is better than implicit for security

#### Profile Structure

Every module follows the same pattern for profile definition in `main.tf`:

```hcl
resource "incus_profile" "service" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit      # Configurable CPU cores
    "limits.memory"         = var.memory_limit   # Configurable RAM
    "limits.memory.enforce" = "hard"             # Strict memory enforcement
  }

  # Root disk with size limit (prevents DoS via storage exhaustion)
  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool  # Default: "local"
      size = var.root_disk_size # Configurable, e.g., "1GB" or "2GB"
    }
  }

  # Optional: Additional devices (storage volumes, extra NICs)
}
```

Network connectivity is provided by profiles passed via `var.profiles` (e.g., `management_network_profile`).

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

#### Profile Design Principles

1. **Explicit over Implicit**: No default profile means explicit control over network access
2. **Consistency**: All modules follow identical profile composition patterns
3. **Modularity**: Base profiles are defined in base-infrastructure module, reused everywhere
4. **Flexibility**: Variable-driven configuration for all limits
5. **Security**: Containers only have network access they explicitly need
6. **Separation of Concerns**: container-base handles boot settings, service profiles handle root disk, network profiles handle connectivity

This approach enables easy scaling - new instances reuse the proven profile pattern with customized resource limits while maintaining network isolation.

### Adding New Service Modules

**For public-facing services (with Caddy reverse proxy):**

Using system containers (recommended):
1. Create Terraform module in `terraform/modules/yourservice/`
2. Set default image to `images:alpine/3.21/cloud`
3. Create `templates/cloud-init.yaml.tftpl` for service configuration
4. Add `domain`, `allowed_ip_range`, and port variables to module
5. Create `templates/caddyfile.tftpl` for reverse proxy config
6. Add `caddy_config_block` output using templatefile()
7. Instantiate module in [terraform/main.tf](terraform/main.tf)
8. Add module's `caddy_config_block` to Caddy's `service_blocks` list

Using OCI containers (only for services requiring custom builds):
1. Create Docker image in `docker/yourservice/` with Dockerfile
2. Add service to GitHub Actions matrix in `.github/workflows/release.yml`
3. Create Terraform module and set image to `ghcr:accuser-dev/atlas/yourservice:latest`
4. Push to GitHub to build and publish image

**For internal-only services (no public access):**

1. Create Terraform module in `terraform/modules/yourservice/`
2. Set default image to `images:alpine/3.21/cloud`
3. Create `templates/cloud-init.yaml.tftpl` for service configuration
4. Add storage and network configuration to module
5. Add endpoint output for internal connectivity
6. Instantiate module in [terraform/main.tf](terraform/main.tf)
7. Connect from other services using `yourservice.incus:port`

**Example - Adding a new Grafana instance:**

Add to `terraform/main.tf`:
```hcl
module "grafana02" {
  source = "./modules/grafana"

  instance_name = "grafana02"
  profile_name  = "grafana02"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  domain           = "grafana-dev.accuser.dev"
  allowed_ip_range = "192.168.68.0/22"  # Required: Set to your network CIDR

  admin_user     = "admin"
  admin_password = "secure-password"

  enable_data_persistence = true
  data_volume_name        = "grafana02-data"
  data_volume_size        = "10GB"
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
- Most services use Alpine Linux system containers with cloud-init
- OCI containers (Docker images) only used for Caddy and Atlantis
- Each service type has its own Terraform module in `terraform/modules/`
- Modules are instantiated in the root [terraform/main.tf](terraform/main.tf)
- Easy to scale by adding new module instances
- Module parameters allow customization per instance

**Container Configuration Flow:**
1. Module defines profile with resource limits and root disk
2. Module creates storage volume (if persistence enabled)
3. Module creates container with cloud-init configuration
4. cloud-init installs packages and configures services at boot
5. Root module orchestrates dependencies and network setup

**Dynamic Configuration:**
- Services declare their own reverse proxy configuration
- Caddy module assembles configurations into complete Caddyfile
- Type-safe: All values validated by Terraform
- DRY principle: No duplicate configuration

**Network Architecture:**
- Two managed networks: production (10.10.0.0/24), management (10.20.0.0/24)
- Optional gitops network (10.30.0.0/24) when `enable_gitops = true`
- Optional IPv6 dual-stack support using ULA addresses (fd00:10:XX::1/64)
- Production network: public-facing services (Mosquitto)
- Management network: internal services (monitoring stack: Grafana, Loki, Prometheus)
- Services on same network can communicate via internal DNS
- Caddy reverse proxy with multi-NIC setup (production, management, optional external)
- IP-based access control for security
- Automatic HTTPS via Let's Encrypt with Cloudflare DNS validation

**Production Network Modes:**
- **Bridge mode** (default): NAT'd network with proxy devices for external access
  - Caddy has 3 NICs: production, management, external (incusbr0)
  - Mosquitto exposed via proxy devices on host ports
- **Physical mode** (IncusOS): Direct LAN attachment via physical interface
  - **Prerequisites:** Enable 'instances' role on the interface: `incus network set eno1 role instances`
  - Set `production_network_name`, `production_network_type`, and `production_network_parent`
  - **Best practice:** Set `production_network_name` to match the interface name (e.g., `eno1`) to avoid ghost networks
  - Caddy has 2 NICs: production (direct LAN), management
  - Mosquitto gets LAN IP directly - no proxy devices needed
  - Containers accessible on LAN via their IPs

**IncusOS Physical Network Example:**
```hcl
# In terraform.tfvars
production_network_name   = "eno1"      # Match interface name
production_network_type   = "physical"
production_network_parent = "eno1"      # Physical LAN interface
```

**Note:** If the physical network already exists in Incus (common on IncusOS), import it before applying:
```bash
tofu import module.base.incus_network.production eno1
```

**IPv6 Configuration:**
- IPv6 is disabled by default (set to empty string)
- Enable by setting `*_network_ipv6` variables in terraform.tfvars
- Uses ULA (Unique Local Address) prefix fd00::/8 for private addressing
- NAT66 configurable per-network via `*_network_ipv6_nat` variables
- Example: `production_network_ipv6 = "fd00:10:10::1/64"`

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

Services expose health check endpoints that Prometheus scrapes:
- Caddy: HTTP check on admin API (`:2019/metrics`)
- Grafana: HTTP check on `/api/health`
- Loki: HTTP check on `/ready`
- Prometheus: HTTP check on `/-/ready`
- step-ca: ACME health endpoint
- Node Exporter: HTTP check on `/metrics`

System containers use OpenRC for service management. Check service status with:
```bash
incus exec <container> -- rc-service <service-name> status
```

**Infrastructure Monitoring:**

4. **Node Exporter** (internal) - Host-level metrics collection
   - Endpoint: `http://node-exporter01.incus:9100`
   - Uses Alpine Linux system container with cloud-init (no Docker image)
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

### Container Image Configuration

**System Containers (Alpine + cloud-init)**

Most services use Alpine Linux system containers with cloud-init configuration:
- Grafana: `images:alpine/3.21/cloud`
- Loki: `images:alpine/3.21/cloud`
- Prometheus: `images:alpine/3.21/cloud`
- step-ca: `images:alpine/3.21/cloud`
- Node Exporter: `images:alpine/3.21/cloud`
- Alertmanager: `images:alpine/3.21/cloud`
- Mosquitto: `images:alpine/3.21/cloud`
- CoreDNS: `images:alpine/3.21/cloud`
- Cloudflared: `images:alpine/3.21/cloud`

These containers:
- Download and install binaries at first boot via cloud-init
- Use OpenRC for service management
- Store configuration in Terraform templates (`templates/cloud-init.yaml.tftpl`)
- Require no external image registry

**OCI Container Images (Docker)**

Services requiring custom builds use GitHub Container Registry:
- Caddy: `ghcr:accuser-dev/atlas/caddy:latest`
- Atlantis: `ghcr:accuser-dev/atlas/atlantis:latest`

**Image Reference Format (ghcr: vs ghcr.io/)**

Terraform modules use `ghcr:` prefix (e.g., `ghcr:accuser-dev/atlas/caddy:latest`) which references an **Incus remote** named "ghcr" that points to `https://ghcr.io`. This is not a typo - it's Incus-specific syntax.

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
- `release.yml` - Build and publish OCI images (main branch only)

**Image Publishing Workflow (OCI containers only):**

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

**For system containers (recommended):**
- ✅ **Cloud-init** - Primary method for configuration (`images:alpine/3.21/cloud`)
- ✅ **File injection** - Use Terraform `file` blocks for post-boot configuration
- ✅ **Version variables** - Pin service versions via Terraform variables
- ⚠️ **External scripts** - Use `incus exec` via separate orchestration script
- ❌ **Terraform provisioners** - Avoid (fragile and non-declarative)

**For OCI containers (Caddy, Atlantis):**
- ✅ **Custom Docker images** - Pre-install packages and plugins
- ✅ **Environment variables** - Configure at runtime via Terraform
- ✅ **File injection** - Use Terraform `file` blocks for configuration files
- ❌ **Cloud-init** - Not available for Docker protocol images

## Important Notes

- The `terraform/terraform.tfvars` file is gitignored and must be created manually with required secrets
- Most services use Alpine Linux system containers (`images:alpine/3.21/cloud`) with cloud-init
- Only Caddy and Atlantis use OCI containers from GitHub Container Registry (ghcr.io)
- OCI images are automatically built and published by the Release workflow on push to main
- Access to services requires explicit `allowed_ip_range` configuration (no default for security)
- Services are distributed across production (10.10.0.0/24) and management (10.20.0.0/24) networks
- Storage volumes use the `local` storage pool and are created automatically when modules are applied
- Each module has a `versions.tf` specifying the Incus provider requirement

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
- `coredns_dns_endpoint` - Internal DNS endpoint using .incus DNS
- `coredns_ipv4_address` - CoreDNS IPv4 address (use for DHCP DNS server configuration)
- `coredns_external_port` - External DNS port on host (bridge mode only)
- `coredns_health_endpoint` - CoreDNS health check endpoint URL
- `coredns_metrics_endpoint` - CoreDNS Prometheus metrics endpoint URL
- `coredns_zone_file` - Generated DNS zone file content (for debugging)
- `cloudflared_metrics_endpoint` - Cloudflared metrics endpoint (if enabled)
- `cloudflared_instance_status` - Cloudflared instance status (if enabled)
- `incus_metrics_endpoint` - Incus metrics endpoint URL being scraped by Prometheus
- `incus_metrics_certificate_fingerprint` - Fingerprint of the metrics certificate registered with Incus
- `incus_loki_logging_name` - Name of the Incus logging configuration for Loki
- `incus_loki_address` - Loki address configured for Incus logging
