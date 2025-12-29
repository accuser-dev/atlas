# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-environment Terraform infrastructure project that manages Incus containers across multiple hosts. The project supports two environments with separate Terraform state:

- **`iapetus`** - Control plane / aggregation (IncusOS standalone host)
- **`cluster01`** - Production workloads (3-node IncusOS cluster)

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         iapetus (IncusOS)                           │
│                    Control Plane / Aggregation                      │
├─────────────────────────────────────────────────────────────────────┤
│  - Atlantis (GitOps) → manages iapetus + cluster via remote Incus   │
│  - Grafana (central dashboards)                                     │
│  - Prometheus (federated, pulls from cluster)                       │
│  - Loki (aggregated logs via Promtail on cluster)                   │
│  - Cloudflared (tunnel ingress)                                     │
│  - step-ca (central CA for all environments)                        │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ incus remote + prometheus federation
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    cluster01 (IncusOS 3-node cluster)               │
│                        Production Workloads                         │
├─────────────────────────────────────────────────────────────────────┤
│  - Prometheus (local scraping, federated by iapetus)                │
│  - Promtail → ships logs to iapetus Loki                            │
│  - node-exporter × 3 (pinned to each cluster node)                  │
│  - Mosquitto, CoreDNS, Alertmanager                                 │
└─────────────────────────────────────────────────────────────────────┘
```

The project is organized into three main directories:
- **`docker/`** - Custom Docker images (Atlantis only)
- **`modules/`** - Shared Terraform modules used by both environments
- **`environments/`** - Environment-specific Terraform configurations

## Resource Requirements

### Compute Resources

**iapetus (Control Plane):**

| Service | CPU (cores) | Memory | Purpose |
|---------|-------------|--------|---------|
| Grafana | 2 | 1GB | Dashboards, visualization |
| Prometheus | 2 | 2GB | Metrics storage (federated) |
| Loki | 2 | 2GB | Log aggregation |
| step-ca | 1 | 512MB | Certificate authority |
| Node Exporter | 1 | 128MB | Host metrics |
| Cloudflared | 1 | 256MB | Tunnel client (optional) |
| Atlantis | 2 | 1GB | GitOps controller (optional) |
| **Total** | **9-11** | **5.9-6.9GB** | |

**cluster (Production Workloads):**

| Service | CPU (cores) | Memory | Purpose |
|---------|-------------|--------|---------|
| Prometheus | 2 | 2GB | Local metrics scraping |
| Alertmanager | 1 | 256MB | Alert routing |
| Node Exporter × 3 | 3 | 384MB | Host metrics (pinned per node) |
| Promtail | 1 | 256MB | Log shipping to iapetus |
| Mosquitto | 1 | 256MB | MQTT broker |
| CoreDNS | 1 | 128MB | Split-horizon DNS |
| **Total** | **9** | **3.3GB** | |

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

### OVN Overlay Networking (Optional)

OVN (Open Virtual Network) provides overlay networking for cross-environment connectivity. When enabled, it replaces bridge/physical networks with OVN networks that can span multiple Incus servers.

**Benefits:**
- Cross-environment `.incus` DNS resolution (e.g., cluster01's promtail can reach iapetus's loki01.incus)
- Native OVN load balancers replace proxy devices
- LAN-routable VIPs for external service access
- Network ACLs for security policies

**Architecture with OVN:**
```
                    OVN Interconnect (Geneve tunnels)
iapetus ◄─────────────────────────────────────────────► cluster01
   │              (Network Integration)                     │
   │                                                        │
   ├── ovn-management (10.20.0.0/24) ◄──── same L2 ────► ovn-management
   │   └── loki01, prometheus01, grafana01                  └── promtail01, prometheus01
   │
   └── ovn-production (10.10.0.0/24) ◄──── same L2 ────► ovn-production
       └── coredns01                                        └── mosquitto01, coredns01
           └── OVN LB VIP: 192.168.68.12                        └── OVN LB VIPs: 192.168.68.10-11
```

**OVN Central (Container-Based):**

OVN Central runs as a Terraform-managed container (`ovn-central01`) on cluster01's incusbr0 network:
- Runs OVN northbound and southbound databases
- Uses proxy devices to expose ports on the physical network (192.168.71.5:6641/6642)
- IncusOS nodes connect as OVN chassis pointing to the container

**Setup Steps:**
1. Deploy ovn-central01 container: `tofu apply -target=module.ovn_central`
2. Configure each IncusOS node as chassis:
   ```bash
   incus admin os service edit ovn --target=<node> << 'EOF'
   {"config": {"database": "tcp:192.168.71.5:6642", "enabled": true, "tunnel_address": "<node-ip>"}}
   EOF
   ```
3. Set Incus OVN config (or use `skip_ovn_config=true` if using HAProxy):
   ```bash
   incus config set network.ovn.northbound_connection=tcp:192.168.71.5:6641
   ```
4. Apply remaining Terraform: `tofu apply`

**Configuration:**
```hcl
# In terraform.tfvars
network_backend    = "ovn"
ovn_uplink_network = "eno1"  # Physical network with ipv4.ovn.ranges configured

# Skip OVN daemon config when using HAProxy (causes ETag mismatch errors)
skip_ovn_config = true

# OVN load balancer VIPs (must be in uplink's ipv4.ovn.ranges)
mosquitto_lb_address = "192.168.68.10"  # cluster01
coredns_lb_address   = "192.168.68.11"  # cluster01
```

**Known Issue:** When accessing clusters via HAProxy load balancer, the `incus_server` resource may fail with ETag mismatch errors due to requests hitting different cluster nodes. Set `skip_ovn_config=true` and configure OVN via CLI instead.

**LAN VIP Allocation:**
| VIP | Service | Environment |
|-----|---------|-------------|
| 192.168.68.10 | Mosquitto | cluster01 |
| 192.168.68.11 | CoreDNS | cluster01 |
| 192.168.68.12 | CoreDNS | iapetus |

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
├── modules/                   # Shared Terraform modules (used by all environments)
│   ├── alertmanager/
│   ├── atlantis/
│   ├── base-infrastructure/
│   ├── cloudflared/
│   ├── coredns/
│   ├── grafana/
│   ├── incus-loki/
│   ├── incus-metrics/
│   ├── incus-vm/
│   ├── loki/
│   ├── mosquitto/
│   ├── node-exporter/
│   ├── ovn-load-balancer/     # OVN load balancers (optional, for OVN backend)
│   ├── prometheus/
│   ├── promtail/              # Log shipping to central Loki
│   └── step-ca/
│
├── environments/
│   ├── iapetus/               # Control plane environment
│   │   ├── main.tf            # Module instantiations for iapetus
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── locals.tf
│   │   ├── providers.tf       # provider "incus" {} (local/default)
│   │   ├── versions.tf        # backend "s3" with iapetus bucket
│   │   ├── terraform.tfvars   # (gitignored)
│   │   ├── backend.hcl        # (gitignored)
│   │   ├── init.sh
│   │   └── bootstrap/         # Creates S3 bucket for state
│   │
│   └── cluster01/             # Production cluster environment
│       ├── main.tf            # Module instantiations for cluster
│       ├── variables.tf
│       ├── outputs.tf
│       ├── locals.tf
│       ├── providers.tf       # provider "incus" {} (uses INCUS_REMOTE)
│       ├── versions.tf        # backend "s3" with cluster bucket
│       ├── terraform.tfvars   # (gitignored)
│       ├── backend.hcl        # (gitignored)
│       └── init.sh
│
├── docker/                    # Custom Docker images (Atlantis only)
│   └── atlantis/
│       ├── Dockerfile
│       └── README.md
│
├── .github/workflows/
│   ├── ci.yml                 # Validates all environments
│   ├── release.yml            # Build Atlantis image
│   └── cleanup.yml
│
├── Makefile                   # ENV=iapetus make plan (default: iapetus)
├── CONTRIBUTING.md
├── BACKUP.md
└── CLAUDE.md                  # This file
```

## Common Commands

### First-Time Setup (Fresh Incus Installation)

For a vanilla Incus installation (after `incus admin init`):

```bash
# 1. Bootstrap iapetus (creates storage bucket for Terraform state)
make bootstrap

# 2. Initialize OpenTofu with remote backend
make init

# 3. Deploy iapetus infrastructure
make deploy

# For cluster environment, configure remote first:
incus remote add cluster01 https://<cluster-ip>:8443
export INCUS_REMOTE=cluster01

# Then deploy cluster01
ENV=cluster01 make init
ENV=cluster01 make deploy
```

### Build and Deployment (Makefile)

All Makefile commands support the `ENV` variable to target specific environments:
- `ENV=iapetus` (default) - Control plane environment
- `ENV=cluster01` - Production cluster environment

```bash
# Bootstrap commands (run once per environment)
make bootstrap           # Complete bootstrap process (iapetus)
ENV=cluster01 make bootstrap  # Bootstrap cluster01 environment

# Build Docker images locally (for testing only)
make build-all
make build-atlantis

# OpenTofu operations (after bootstrap)
make init                # Initialize iapetus with remote backend
make plan                # Plan changes for iapetus
make apply               # Apply changes to iapetus
make destroy             # Destroy iapetus infrastructure

# Target cluster01 environment
ENV=cluster01 make init    # Initialize cluster01
ENV=cluster01 make plan    # Plan cluster01 changes
ENV=cluster01 make apply   # Apply to cluster01

# Complete deployment
make deploy              # Deploy iapetus
ENV=cluster01 make deploy  # Deploy cluster01

# Cleanup
make clean               # Clean all build artifacts
make clean-docker        # Clean Docker build cache
make clean-tofu          # Clean OpenTofu cache for current ENV
make clean-images        # Remove Atlas images from Incus cache

# Format OpenTofu files
make format

# Backup operations (environment-specific)
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
make init                     # iapetus
ENV=cluster01 make init         # cluster01

# Option 2: Use the init wrapper script
cd environments/iapetus && ./init.sh
cd environments/cluster01 && ./init.sh

# Option 3: Manual with backend config
cd environments/iapetus && tofu init -backend-config=backend.hcl
cd environments/cluster01 && tofu init -backend-config=backend.hcl
```

After initialization, you can run other commands directly:
```bash
cd environments/iapetus  # or environments/cluster01

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

Each environment uses its own Incus S3-compatible storage bucket for encrypted remote state storage:
- `iapetus` state → S3 bucket on iapetus host
- `cluster` state → S3 bucket on cluster

This provides:
- Encrypted state at rest
- Self-hosted (no external dependencies)
- S3-compatible API
- Separate state per environment
- Secure credential-based access

**Bootstrap Process:**

Each environment has a **two-project structure**:
1. **Bootstrap project** (`environments/*/bootstrap/`) - Uses local state, creates storage bucket
2. **Main project** (`environments/*/`) - Uses remote state in the storage bucket

**Initial Setup (Automated):**

```bash
# Run bootstrap for iapetus
make bootstrap

# Bootstrap creates:
# - Incus storage buckets configuration
# - Storage pool (terraform-state)
# - Storage bucket (atlas-terraform-state)
# - S3 credentials
# - Backend config file (environments/iapetus/backend.hcl)

# For cluster01, configure remote first then bootstrap:
incus remote add cluster01 https://<cluster-ip>:8443
export INCUS_REMOTE=cluster01
ENV=cluster01 make bootstrap
```

See [environments/iapetus/BACKEND_SETUP.md](environments/iapetus/BACKEND_SETUP.md) for detailed instructions.

**Working with Remote State:**

```bash
# Normal operations work the same
cd environments/iapetus  # or environments/cluster
tofu plan
tofu apply

# State is automatically stored remotely
tofu state list

# Migrate existing local state (if needed)
tofu init -migrate-state
```

**Important Notes:**
- Never commit `backend.hcl` (gitignored)
- Each environment has its own state bucket and credentials
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

The project uses Terraform modules for scalability and reusability. Modules are shared across environments.

**Environment Level (iapetus or cluster):**
- `environments/*/versions.tf` - Terraform and provider version constraints
- `environments/*/providers.tf` - Provider configuration
- `environments/*/variables.tf` - Environment-specific variable definitions
- `environments/*/main.tf` - Module instantiations for that environment
- `environments/*/locals.tf` - Centralized service configuration
- `environments/*/outputs.tf` - Output values (endpoints, configurations)
- `environments/*/terraform.tfvars` - Variable values (gitignored, contains secrets)

**Shared Terraform Modules:**
- [modules/grafana/](modules/grafana/) - Grafana observability platform
  - [main.tf](modules/grafana/main.tf) - Profile, container, and storage volume
  - [variables.tf](modules/grafana/variables.tf) - Module input variables including domain config
  - [outputs.tf](modules/grafana/outputs.tf) - Module outputs
  - [templates/cloud-init.yaml.tftpl](modules/grafana/templates/cloud-init.yaml.tftpl) - Cloud-init configuration
  - [versions.tf](modules/grafana/versions.tf) - Provider requirements

- [modules/loki/](modules/loki/) - Log aggregation system (internal only)
  - [main.tf](modules/loki/main.tf) - Profile, container, and storage volume
  - [variables.tf](modules/loki/variables.tf) - Module input variables
  - [outputs.tf](modules/loki/outputs.tf) - Module outputs including endpoint

- [modules/prometheus/](modules/prometheus/) - Metrics collection and storage
  - [main.tf](modules/prometheus/main.tf) - Profile, container, storage volume, and config file
  - [variables.tf](modules/prometheus/variables.tf) - Module input variables including prometheus.yml config
  - [outputs.tf](modules/prometheus/outputs.tf) - Module outputs including endpoint

- [modules/promtail/](modules/promtail/) - Log shipping agent (cluster → iapetus)
  - [main.tf](modules/promtail/main.tf) - Profile and container
  - [variables.tf](modules/promtail/variables.tf) - Module input variables including loki_push_url
  - [outputs.tf](modules/promtail/outputs.tf) - Module outputs
  - [templates/cloud-init.yaml.tftpl](modules/promtail/templates/cloud-init.yaml.tftpl) - Cloud-init configuration

- [modules/node-exporter/](modules/node-exporter/) - Host metrics collection
  - Supports `target_node` variable for cluster pinning (one per physical host)

**Docker Images:**
- [docker/atlantis/](docker/atlantis/) - Custom Atlantis image with OpenTofu support
  - [Dockerfile](docker/atlantis/Dockerfile) - Image build definition
  - [README.md](docker/atlantis/README.md) - GitOps configuration instructions

### Infrastructure Components

1. **Incus Provider**
   - Uses the `lxc/incus` provider (v1.0.0+)
   - Manages LXC/Incus containers and storage volumes
   - iapetus uses local/default remote
   - cluster uses INCUS_REMOTE environment variable to target remote cluster

2. **Network Configuration** ([modules/base-infrastructure/](modules/base-infrastructure/))
   - Two managed networks: production (10.10.0.0/24), management (10.20.0.0/24)
   - Optional gitops network (10.30.0.0/24) when `enable_gitops = true`
   - Optional IPv6 support (dual-stack) using ULA addresses (e.g., fd00:10:10::1/64)
   - NAT enabled for external connectivity (configurable for both IPv4 and IPv6)
   - Management network hosts internal services (monitoring stack)

3. **Grafana Module** ([modules/grafana/](modules/grafana/))
   - Visualization and dashboarding platform
   - Uses Alpine Linux system container with cloud-init
   - Persistent storage for dashboards and configuration (10GB)
   - Admin credentials configured via Terraform variables
   - Domain configuration for Cloudflare Tunnel access
   - Datasources and dashboards provisioned via cloud-init

4. **Grafana Instance** (instantiated in [environments/iapetus/main.tf](environments/iapetus/main.tf))
   - Instance name: `grafana01`
   - Image: `images:alpine/3.21/cloud` (system container)
   - Domain: `grafana.accuser.dev` (accessible via Cloudflare Tunnel)
   - Resource limits: 2 CPUs, 1GB memory
   - Storage: 10GB persistent volume for `/var/lib/grafana`
   - Network: Connected to management network

5. **Loki Module** ([modules/loki/](modules/loki/))
   - Log aggregation system (internal only)
   - Uses Alpine Linux system container with cloud-init (no Docker image)
   - Persistent storage for log data (50GB)
   - Configurable retention (default: 30 days / 720h)
   - No public-facing reverse proxy configuration
   - Internal endpoint for Grafana data source

6. **Loki Instance** (instantiated in [environments/iapetus/main.tf](environments/iapetus/main.tf))
   - Instance name: `loki01`
   - Image: `images:alpine/3.21/cloud` (system container)
   - Internal endpoint: `http://loki01.incus:3100`
   - Resource limits: 2 CPUs, 2GB memory
   - Storage: 50GB persistent volume for `/loki`
   - Retention: 30 days (720h) with 2h delete delay
   - Network: Connected to management network (internal only)

7. **Prometheus Module** ([modules/prometheus/](modules/prometheus/))
   - Metrics collection and time-series database (internal only)
   - Uses Alpine Linux system container with cloud-init (no Docker image)
   - Persistent storage for metrics data (100GB)
   - Configurable retention (time-based and size-based)
   - prometheus.yml configuration via Terraform variable
   - No public-facing reverse proxy configuration
   - Internal endpoint for Grafana data source

8. **Prometheus Instance** (both environments)
    - Instance name: `prometheus01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Internal endpoint: `http://prometheus01.incus:9090`
    - Resource limits: 2 CPUs, 2GB memory
    - Storage: 100GB persistent volume for `/prometheus`
    - Retention: 30 days (time-based), no size limit by default
    - Network: Connected to management network (internal only)

9. **step-ca Module** ([modules/step-ca/](modules/step-ca/))
    - Internal ACME Certificate Authority for TLS certificates
    - Uses Alpine Linux system container with cloud-init (no Docker image)
    - Persistent storage for CA data and certificates (1GB)
    - Configurable CA name and DNS names
    - ACME endpoint for automated certificate issuance
    - Internal endpoint for services requesting certificates

10. **step-ca Instance** (instantiated in [environments/iapetus/main.tf](environments/iapetus/main.tf))
    - Instance name: `step-ca01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - CA name: "Atlas Internal CA"
    - DNS names: `step-ca01.incus,step-ca01,localhost`
    - ACME endpoint: `https://step-ca01.incus:9000`
    - Resource limits: 1 CPU, 512MB memory
    - Storage: 1GB persistent volume for `/home/step`
    - Network: Connected to management network (internal only)
    - CA fingerprint: Retrieved after deployment via `incus exec step-ca01 -- cat /home/step/fingerprint`

11. **Alertmanager Module** ([modules/alertmanager/](modules/alertmanager/))
    - Alert routing and notification management (internal only)
    - Uses Alpine Linux system container with cloud-init (no Docker image)
    - Persistent storage for silences and notification state (1GB)
    - Configurable notification routes (Slack, email, webhook)
    - Silencing and inhibition rules support
    - Integration with Prometheus via alertmanagers config

12. **Alertmanager Instance** (instantiated in cluster environment)
    - Instance name: `alertmanager01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Internal endpoint: `http://alertmanager01.incus:9093`
    - Resource limits: 1 CPU, 256MB memory
    - Storage: 1GB persistent volume for `/var/lib/alertmanager`
    - Network: Connected to management network (internal only)
    - Prometheus integration: Configured via `alerting.alertmanagers` in prometheus.yml

13. **Mosquitto Module** ([modules/mosquitto/](modules/mosquitto/))
    - Eclipse Mosquitto MQTT broker for IoT messaging
    - Uses Alpine Linux system container with cloud-init (no Docker image)
    - External access via Incus proxy devices (pattern for TCP services)
    - Persistent storage for retained messages and subscriptions
    - Optional TLS support via step-ca
    - Password file authentication support

14. **Mosquitto Instance** (instantiated in cluster environment)
    - Instance name: `mosquitto01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Internal endpoint: `mqtt://mosquitto01.incus:1883`
    - External access: Host ports 1883 (MQTT) and 8883 (MQTTS) via proxy devices
    - Resource limits: 1 CPU, 256MB memory
    - Storage: 5GB persistent volume for `/mosquitto/data`
    - Network: Connected to production network (externally accessible)

15. **CoreDNS Module** ([modules/coredns/](modules/coredns/))
    - Split-horizon DNS server for internal service resolution
    - Uses Alpine Linux system container with cloud-init (no Docker image)
    - Authoritative for internal zone (e.g., `accuser.dev`)
    - Forwards `.incus` queries to Incus DNS resolver
    - Forwards external queries to upstream DNS (Cloudflare, Google)
    - External access via Incus proxy devices (UDP+TCP on port 53)
    - Zone file generated from Terraform service module outputs

16. **CoreDNS Instance** (instantiated in cluster environment)
    - Instance name: `coredns01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Internal endpoint: `coredns01.incus:53`
    - External access: Host port 53 (UDP+TCP) via proxy devices (bridge mode)
    - Resource limits: 1 CPU, 128MB memory
    - Network: Connected to production network (LAN accessible)
    - Health endpoint: `http://coredns01.incus:8080/health`
    - Metrics endpoint: `http://coredns01.incus:9153/metrics`

17. **Cloudflared Module** ([modules/cloudflared/](modules/cloudflared/))
    - Cloudflare Tunnel client for secure remote access via Zero Trust
    - Uses Alpine Linux system container with cloud-init (no Docker image)
    - Token-based authentication (managed via Cloudflare dashboard)
    - Metrics endpoint for Prometheus scraping
    - No persistent storage required (stateless)

18. **Cloudflared Instance** (instantiated in iapetus environment)
    - Instance name: `cloudflared01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Metrics endpoint: `http://cloudflared01.incus:2000`
    - Resource limits: 1 CPU, 256MB memory
    - Network: Connected to management network (internal access to all services)
    - Conditionally deployed: Only created when `cloudflared_tunnel_token` is set

19. **Incus Metrics Module** ([modules/incus-metrics/](modules/incus-metrics/))
    - Generates mTLS certificates for scraping Incus container metrics
    - Uses Terraform TLS provider for certificate generation (ECDSA P-384)
    - Registers certificate with Incus as type "metrics"
    - Outputs certificate and private key for injection into Prometheus
    - No Docker image required (certificate management only)

20. **Incus Metrics** (instantiated in both environments)
    - Certificate name: `prometheus-metrics`
    - Metrics endpoint: `https://<management-gateway>:8443/1.0/metrics`
    - Certificate validity: 10 years (3650 days)
    - Conditionally deployed: Only created when `enable_incus_metrics` is true (default)
    - Provides container-level metrics: CPU, memory, disk, network, processes

21. **Incus Loki Module** ([modules/incus-loki/](modules/incus-loki/))
    - Configures native Incus logging to Loki (no Promtail required)
    - Pushes lifecycle events (instance start/stop, create, delete)
    - Pushes logging events (container and VM log output)
    - Uses Incus server-level configuration
    - No Docker image required (server configuration only)

22. **Incus Loki** (instantiated in iapetus environment)
    - Logging name: `loki01`
    - Target address: `http://loki01.incus:3100`
    - Event types: `lifecycle,logging`
    - Conditionally deployed: Only created when `enable_incus_loki` is true (default)
    - Logs queryable in Grafana via Loki datasource

23. **Atlantis Module** ([modules/atlantis/](modules/atlantis/))
    - GitOps controller for PR-based infrastructure management
    - Automatic `terraform plan` on PR creation/update
    - Apply changes via PR comment `atlantis apply`
    - Webhook endpoint accessible via Cloudflare Tunnel
    - Persistent storage for plans cache and locks (10GB)
    - Custom Docker image: [docker/atlantis/](docker/atlantis/)

24. **Atlantis Instance** (instantiated in iapetus environment)
    - Instance name: `atlantis01`
    - Image: `ghcr.io/accuser-dev/atlas/atlantis:latest` (published from [docker/atlantis/](docker/atlantis/))
    - Webhook endpoint: `https://<atlantis_domain>/events`
    - Resource limits: 2 CPUs, 1GB memory

25. **Promtail Module** ([modules/promtail/](modules/promtail/))
    - Log shipping agent for forwarding logs to central Loki
    - Uses Alpine Linux system container with cloud-init
    - Scrapes journal logs and system logs
    - Ships to iapetus Loki via HTTP

26. **Promtail Instance** (instantiated in cluster environment)
    - Instance name: `promtail01`
    - Image: `images:alpine/3.21/cloud` (system container)
    - Internal endpoint: `http://promtail01.incus:9080`
    - Resource limits: 1 CPU, 256MB memory
    - Network: Connected to management network
    - Ships logs to: `http://loki01.iapetus:3100/loki/api/v1/push`

### External TCP Service Pattern (Proxy Devices)

For non-HTTP services that need external access (like MQTT, DNS), the project uses Incus proxy devices:

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
- Port conflicts must be managed manually
- Each service manages its own TLS (via step-ca)

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
- Cloudflare Tunnel terminates external TLS for public-facing services

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
| Grafana | 2 cores       | 1GB             | 1-64 CPUs, MB/GB format |
| Loki    | 2 cores       | 2GB             | 1-64 CPUs, MB/GB format |
| Prometheus | 2 cores    | 2GB             | 1-64 CPUs, MB/GB format |
| step-ca | 1 core        | 512MB           | 1-64 CPUs, MB/GB format |
| Alertmanager | 1 core   | 256MB           | 1-64 CPUs, MB/GB format |
| Mosquitto | 1 core      | 256MB           | 1-64 CPUs, MB/GB format |
| Cloudflared | 1 core    | 256MB           | 1-64 CPUs, MB/GB format |
| Atlantis | 2 cores      | 1GB             | 1-64 CPUs, MB/GB format |

All limits are validated at the Terraform variable level to ensure correctness before deployment.

#### Profile Naming Convention

Profiles follow a simple, service-specific naming pattern:

| Service | Profile Name | Instance Name |
|---------|--------------|---------------|
| Grafana | `grafana`    | `grafana01`   |
| Loki    | `loki`       | `loki01`      |
| Prometheus | `prometheus` | `prometheus01` |
| step-ca | `step-ca`    | `step-ca01`   |
| Alertmanager | `alertmanager` | `alertmanager01` |
| Mosquitto | `mosquitto` | `mosquitto01` |
| Cloudflared | `cloudflared` | `cloudflared01` |
| Atlantis | `atlantis`   | `atlantis01`  |

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

**Production network services** (Mosquitto, CoreDNS):
- Single network interface (`eth0`)
- Connected to production network for external/LAN access
- May use proxy devices for port forwarding in bridge mode

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

**For internal services (most common):**

1. Create Terraform module in `modules/yourservice/`
2. Set default image to `images:alpine/3.21/cloud`
3. Create `templates/cloud-init.yaml.tftpl` for service configuration
4. Add storage and network configuration to module
5. Add endpoint output for internal connectivity
6. Instantiate module in the appropriate environment's `main.tf`
7. Connect from other services using `yourservice.incus:port`

**For externally accessible services:**

Configure external access via Cloudflare Tunnel:
1. Create internal service as above
2. Add a public hostname in Cloudflare Zero Trust dashboard
3. Point it to the internal service endpoint (e.g., `http://grafana01.incus:3000`)
4. Configure access policies as needed

**For TCP services needing direct external access (like MQTT):**

Use Incus proxy devices (bridge mode) or direct LAN attachment (physical mode):
1. Create service on production network
2. Add proxy device for port forwarding in bridge mode
3. In physical mode, containers get LAN IPs directly

**For OCI containers (only for services requiring custom builds like Atlantis):**

1. Create Docker image in `docker/yourservice/` with Dockerfile
2. Add service to GitHub Actions matrix in `.github/workflows/release.yml`
3. Create Terraform module in `modules/yourservice/` and set image to `ghcr:accuser-dev/atlas/yourservice:latest`
4. Instantiate in the appropriate environment's `main.tf`
5. Push to GitHub to build and publish image

**Example - Adding a new Grafana instance:**

Add to `environments/iapetus/main.tf`:
```hcl
module "grafana02" {
  source = "../../modules/grafana"

  instance_name = "grafana02"
  profile_name  = "grafana02"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  domain         = "grafana-dev.accuser.dev"
  admin_user     = "admin"
  admin_password = "secure-password"

  enable_data_persistence = true
  data_volume_name        = "grafana02-data"
  data_volume_size        = "10GB"
}
```

Then configure external access via Cloudflare Tunnel dashboard.

### Key Design Patterns

**Modular Architecture:**
- Most services use Alpine Linux system containers with cloud-init
- OCI containers (Docker images) only used for Atlantis
- Each service type has its own Terraform module in `modules/`
- Modules are instantiated in each environment's `main.tf`
- Easy to scale by adding new module instances
- Module parameters allow customization per instance

**Container Configuration Flow:**
1. Module defines profile with resource limits and root disk
2. Module creates storage volume (if persistence enabled)
3. Module creates container with cloud-init configuration
4. cloud-init installs packages and configures services at boot
5. Root module orchestrates dependencies and network setup

**External Access via Cloudflare Tunnel:**
- Cloudflared connects to Cloudflare's edge network
- Zero Trust policies control access to services
- No inbound firewall rules required
- Configure routes in Cloudflare dashboard

**Network Architecture:**
- Two managed networks: production (10.10.0.0/24), management (10.20.0.0/24)
- Optional gitops network (10.30.0.0/24) when `enable_gitops = true`
- Optional IPv6 dual-stack support using ULA addresses (fd00:10:XX::1/64)
- Production network: public-facing services (Mosquitto)
- Management network: internal services (monitoring stack: Grafana, Loki, Prometheus)
- Services on same network can communicate via internal DNS
- External HTTPS access via Cloudflare Tunnel (Zero Trust)

**Production Network Modes:**
- **Bridge mode** (default): NAT'd network with proxy devices for external access
  - Mosquitto exposed via proxy devices on host ports
- **Physical mode** (IncusOS): Direct LAN attachment via physical interface
  - **Prerequisites:** Enable 'instances' role on the interface: `incus network set eno1 role instances`
  - Set `production_network_name`, `production_network_type`, and `production_network_parent`
  - **Best practice:** Set `production_network_name` to match the interface name (e.g., `eno1`) to avoid ghost networks
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

**Access Control:**
- External access managed via Cloudflare Zero Trust policies
- Rate limiting configured in Cloudflare dashboard
- No inbound firewall rules required on infrastructure
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
   - Scrapes metrics from all services (Grafana, Loki, Cloudflared, step-ca, self)
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
- `cloudflared01.incus:2000` - Cloudflared metrics
- `step-ca01.incus:9000` - step-ca health endpoint
- `node-exporter01.incus:9100` - Host system metrics (CPU, memory, disk, network)
- `<management-gateway>:8443` - Incus container metrics (mTLS authenticated)
- `localhost:9090` - Prometheus self-monitoring

Services expose health check endpoints that Prometheus scrapes:
- Grafana: HTTP check on `/api/health`
- Loki: HTTP check on `/ready`
- Prometheus: HTTP check on `/-/ready`
- Cloudflared: HTTP check on `/metrics`
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
   - Edit Terraform modules in `modules/`
   - Modify environment configuration in `environments/*/main.tf`
   - Update variables in `environments/*/terraform.tfvars`

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
- Atlantis: `ghcr:accuser-dev/atlas/atlantis:latest`

**Image Reference Format (ghcr: vs ghcr.io/)**

Terraform modules use `ghcr:` prefix (e.g., `ghcr:accuser-dev/atlas/atlantis:latest`) which references an **Incus remote** named "ghcr" that points to `https://ghcr.io`. This is not a typo - it's Incus-specific syntax.

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

To use official upstream images instead, override the `image` variable in the environment's `main.tf`:

```hcl
module "grafana01" {
  source = "../../modules/grafana"

  # Use official image instead of system container
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

**For OCI containers (Atlantis):**
- ✅ **Custom Docker images** - Pre-install packages and plugins
- ✅ **Environment variables** - Configure at runtime via Terraform
- ✅ **File injection** - Use Terraform `file` blocks for configuration files
- ❌ **Cloud-init** - Not available for Docker protocol images

## Important Notes

- The `environments/*/terraform.tfvars` files are gitignored and must be created manually with required secrets
- Most services use Alpine Linux system containers (`images:alpine/3.21/cloud`) with cloud-init
- Only Atlantis uses OCI containers from GitHub Container Registry (ghcr.io)
- OCI images are automatically built and published by the Release workflow on push to main
- External access is managed via Cloudflare Tunnel and Zero Trust policies
- Services are distributed across production (10.10.0.0/24) and management (10.20.0.0/24) networks
- Storage volumes use the `local` storage pool and are created automatically when modules are applied
- Each module has a `versions.tf` specifying the Incus provider requirement

## Outputs

After applying, use `cd environments/iapetus && tofu output` (or `environments/cluster01`) to view:

**iapetus outputs:**
- `loki_endpoint` - Internal Loki endpoint URL
- `prometheus_endpoint` - Internal Prometheus endpoint URL
- `step_ca_acme_endpoint` - step-ca ACME endpoint URL for certificate requests
- `step_ca_fingerprint_command` - Command to retrieve CA fingerprint for TLS configuration
- `cloudflared_metrics_endpoint` - Cloudflared metrics endpoint (if enabled)
- `incus_metrics_endpoint` - Incus metrics endpoint URL
- `incus_loki_logging_name` - Name of the Incus logging configuration for Loki

**cluster outputs:**
- `prometheus_endpoint` - Prometheus endpoint URL (for iapetus federation)
- `alertmanager_endpoint` - Internal Alertmanager endpoint URL
- `mosquitto_mqtt_endpoint` - Internal MQTT endpoint URL
- `mosquitto_external_ports` - External host ports for MQTT access (1883, 8883)
- `coredns_dns_endpoint` - Internal DNS endpoint
- `coredns_ipv4_address` - CoreDNS IPv4 address
- `node_exporter_endpoints` - Node exporter endpoints for each cluster node
- `promtail_endpoint` - Promtail HTTP API endpoint
- `promtail_loki_target` - Loki URL that Promtail is shipping logs to
- `incus_metrics_endpoint` - Incus metrics endpoint URL
