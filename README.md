# Atlas Infrastructure

A multi-environment OpenTofu infrastructure project for managing Incus containers across multiple hosts, providing a complete observability and monitoring stack.

## Overview

This project manages two Incus environments with separate Terraform state:

- **`iapetus`** - Control plane / aggregation (IncusOS standalone host)
- **`cluster01`** - Production workloads (3-node IncusOS cluster)

### Services by Environment

**iapetus (Control Plane):**
- **Grafana** - Central dashboards and visualization
- **Prometheus** - Federated metrics (pulls from cluster01)
- **Loki** - Aggregated log storage
- **step-ca** - Internal PKI for TLS certificates
- **Cloudflared** - Cloudflare Tunnel for Zero Trust access
- **CoreDNS** - Split-horizon DNS with cross-environment forwarding
- **HAProxy** - TCP/HTTP load balancer (optional)
- **Dex** - OIDC identity provider (optional)
- **OpenFGA** - Fine-grained authorization (optional)
- **Atlantis** - GitOps controller (optional)
- **Node Exporter** - Host metrics

**cluster01 (Production):**
- **Prometheus** - Local metrics scraping
- **Alloy** - Ships logs to iapetus Loki
- **Alertmanager** - Alert routing and notifications
- **Node Exporter × 3** - Host metrics (pinned to each cluster node)
- **Mosquitto** - MQTT broker for IoT messaging
- **CoreDNS** - Split-horizon DNS

All services run in Incus system containers (Alpine Linux + cloud-init) with persistent storage, network isolation, and automatic configuration management.

## Project Structure

```
atlas/
├── modules/                   # Shared Terraform modules (used by all environments)
│   ├── alertmanager/          # Alert routing and notifications
│   ├── alloy/                 # Log collection and shipping (replaces Promtail)
│   ├── atlantis/              # GitOps controller
│   ├── base-infrastructure/   # Networks and base profiles
│   ├── cloudflared/           # Cloudflare Tunnel client
│   ├── coredns/               # Split-horizon DNS
│   ├── dex/                   # OIDC identity provider
│   ├── grafana/               # Visualization platform
│   ├── haproxy/               # TCP/HTTP load balancer
│   ├── incus-loki/            # Native Incus → Loki logging
│   ├── incus-metrics/         # Incus metrics certificates
│   ├── incus-network-zone/    # Incus DNS zone configuration
│   ├── incus-vm/              # Virtual machine support
│   ├── loki/                  # Log aggregation
│   ├── mosquitto/             # MQTT broker
│   ├── node-exporter/         # Host metrics
│   ├── openfga/               # Fine-grained authorization
│   ├── ovn-central/           # OVN databases
│   ├── ovn-config/            # Incus OVN settings
│   ├── ovn-load-balancer/     # OVN load balancers
│   ├── prometheus/            # Metrics collection
│   └── step-ca/               # Internal CA
│
├── environments/
│   ├── iapetus/               # Control plane environment
│   │   ├── main.tf            # Module instantiations
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── locals.tf
│   │   ├── templates/         # Configuration templates
│   │   ├── terraform.tfvars   # Secrets (gitignored)
│   │   └── bootstrap/         # Remote state setup
│   │
│   └── cluster01/             # Production cluster environment
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── locals.tf
│       └── terraform.tfvars   # Secrets (gitignored)
│
├── docker/                    # Custom Docker images (Atlantis only)
│   └── atlantis/
│
├── .github/workflows/         # CI/CD workflows
│   ├── ci.yml                 # Validates both environments
│   └── release.yml            # Build and publish images
│
├── Makefile                   # ENV=iapetus make plan (default: iapetus)
├── CLAUDE.md                  # Detailed architecture documentation
├── CONTRIBUTING.md            # Contribution guidelines
├── BACKUP.md                  # Backup and disaster recovery
├── GITOPS.md                  # GitOps workflow with Atlantis
├── SECURITY.md                # Security documentation
├── TROUBLESHOOTING.md         # Troubleshooting guide
└── README.md                  # This file
```

## Quick Start

### Prerequisites

- [Incus](https://linuxcontainers.org/incus/) installed and running
- [OpenTofu](https://opentofu.org/) >= 1.6 (or Terraform >= 1.6)
- Cloudflare API token (for Cloudflare Tunnel access)
- GitHub account (images published to ghcr.io)

### Initial Setup (iapetus)

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
   cd environments/iapetus
   cp terraform.tfvars.example terraform.tfvars
   # Edit with your values
   ```

4. **Deploy iapetus**:
   ```bash
   make init
   make plan
   make apply
   ```

5. **View outputs**:
   ```bash
   cd environments/iapetus
   tofu output
   ```

### Deploying the Cluster Environment

1. **Configure Incus remote** (from iapetus or management host):
   ```bash
   incus remote add cluster01 https://<cluster-ip>:8443
   export INCUS_REMOTE=cluster01
   ```

2. **Bootstrap cluster state**:
   ```bash
   ENV=cluster01 make bootstrap
   ```

3. **Create terraform.tfvars**:
   ```bash
   cd environments/cluster01
   cp terraform.tfvars.example terraform.tfvars
   # Edit with cluster-specific values including loki_push_url
   ```

4. **Deploy cluster01**:
   ```bash
   ENV=cluster01 make init
   ENV=cluster01 make plan
   ENV=cluster01 make apply
   ```

## Container Images

### System Containers (Alpine + cloud-init)

Most services use Alpine Linux system containers with cloud-init:
- Grafana, Prometheus, Loki, Alertmanager
- step-ca, Cloudflared, Node Exporter
- Mosquitto, CoreDNS, Alloy
- Dex, HAProxy, OpenFGA

These download and configure binaries at first boot - no custom images needed.

### OCI Container Images (Docker)

Only Atlantis uses a custom Docker image:
- **Atlantis**: `ghcr.io/accuser-dev/atlas/atlantis:latest`

Built on every push to `main` and published to GitHub Container Registry.

### Local Development

Build Atlantis image locally for testing:
```bash
make build-atlantis
```

## Usage

### Managing Infrastructure

All commands support the `ENV` variable to target specific environments:

```bash
# iapetus (default)
make init
make plan
make apply
make destroy

# cluster01 environment
ENV=cluster01 make init
ENV=cluster01 make plan
ENV=cluster01 make apply
ENV=cluster01 make destroy
```

### Full Deployment

```bash
# Deploy iapetus
make deploy

# Deploy cluster01
ENV=cluster01 make deploy
```

## Configuration

### Network Configuration

Each environment supports multiple network modes:

**Bridge Networks (default):**
- **production** (10.10.0.0/24) - For external services (Mosquitto, CoreDNS)
- **management** (10.20.0.0/24) - For internal services (monitoring stack, PKI)
- **gitops** (10.30.0.0/24) - For GitOps automation (optional, iapetus only)

**OVN Networks (optional):**
- Provides native load balancers with LAN-routable VIPs
- Supports external access without proxy devices
- Configured via `network_backend = "ovn"` in terraform.tfvars

Configure IP addresses in `environments/*/terraform.tfvars`.

### Cross-Environment Integration

The cluster01 environment connects to iapetus for:
- **Log shipping**: Alloy → iapetus Loki (`loki_push_url` variable)
- **Prometheus federation**: iapetus pulls metrics from cluster01
- **TLS certificates**: step-ca on iapetus issues certs for cluster services
- **DNS forwarding**: Cross-environment DNS resolution via CoreDNS

### Adding New Services

See [CLAUDE.md](CLAUDE.md) for detailed instructions on adding new services.

## Architecture

### Key Features

- **Multi-Environment** - Separate state for iapetus (control plane) and cluster01 (production)
- **Declarative Infrastructure** - Everything defined in OpenTofu
- **Modular Design** - Shared modules across environments
- **System Containers** - Alpine Linux with cloud-init (no custom images for most services)
- **Persistent Storage** - Data survives container restarts with optional automated snapshots
- **Zero Trust Access** - Cloudflare Tunnel for external access
- **Network Isolation** - Separate networks for different service types
- **Native Incus Integration** - Container metrics and logging via Incus API
- **OVN Support** - Optional software-defined networking with load balancers

### Multi-Environment Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         iapetus (IncusOS)                           │
│                    Control Plane / Aggregation                      │
├─────────────────────────────────────────────────────────────────────┤
│  - Atlantis (GitOps) → manages iapetus + cluster via remote Incus   │
│  - Grafana (central dashboards)                                     │
│  - Prometheus (federated, pulls from cluster01)                     │
│  - Loki (aggregated logs via Alloy on cluster01)                    │
│  - Cloudflared (tunnel ingress)                                     │
│  - step-ca (central CA for all environments)                        │
│  - CoreDNS, HAProxy, Dex, OpenFGA (optional)                        │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ incus remote + prometheus federation
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    cluster01 (IncusOS 3-node cluster)               │
│                        Production Workloads                         │
├─────────────────────────────────────────────────────────────────────┤
│  - Prometheus (local scraping, federated by iapetus)                │
│  - Alloy → ships logs to iapetus Loki                               │
│  - node-exporter × 3 (pinned to each cluster node)                  │
│  - Mosquitto, CoreDNS, Alertmanager                                 │
└─────────────────────────────────────────────────────────────────────┘
```

**iapetus Services** (control plane):
- Grafana: `https://grafana.yourdomain.com` (via Cloudflare Tunnel)
- Prometheus: `http://prometheus01.incus:9090`
- Loki: `http://loki01.incus:3100`
- step-ca: `https://step-ca01.incus:9000`

**cluster01 Services** (production):
- Prometheus: `http://prometheus01.incus:9090`
- Alertmanager: `http://alertmanager01.incus:9093`
- Mosquitto: Host ports 1883 (MQTT), 8883 (MQTTS)
- CoreDNS: Host port 53 (DNS)
- Node Exporter × 3: Pinned to each cluster node

### Storage Volumes

**iapetus:**
- `grafana01-data` (10GB) - Dashboards and settings
- `loki01-data` (50GB) - Log storage
- `prometheus01-data` (100GB) - Metrics storage
- `step-ca01-data` (1GB) - CA keys and database
- `atlantis01-data` (10GB) - GitOps state (optional)

**cluster01:**
- `prometheus01-data` (100GB) - Metrics storage
- `alertmanager01-data` (1GB) - Silences and state
- `mosquitto01-data` (5GB) - MQTT retained messages

All volumes support optional automated snapshot scheduling. See [BACKUP.md](BACKUP.md) for details.

## CI/CD

The project uses separate workflows for validation and releases:

### CI Workflow (`ci.yml`)

**Triggers:** Pull requests and pushes to feature branches

**What it does:**
1. OpenTofu format and validation for both environments
2. Atlantis Docker image build (without publish)
3. Security scanning

### Release Workflow (`release.yml`)

**Triggers:** Push to `main` branch

**What it does:**
1. Builds Atlantis Docker image
2. Publishes to GitHub Container Registry
3. Tags with `latest` and commit SHA

## Development

### Makefile Targets

All targets support `ENV=iapetus` (default) or `ENV=cluster01`:

```bash
make help              # Show all available commands

# Bootstrap (first time setup per environment)
make bootstrap         # Set up remote state storage

# OpenTofu operations
make init              # Initialize OpenTofu with remote backend
make plan              # Plan infrastructure changes
make apply             # Apply infrastructure changes
make destroy           # Destroy infrastructure
make deploy            # Apply OpenTofu
make format            # Format OpenTofu files

# Docker operations (Atlantis only)
make build-atlantis    # Build Atlantis image locally

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

- **`modules/`** - Shared Terraform modules
  - Used by both environments
  - Each service has its own directory

- **`environments/`** - Environment-specific configuration
  - `iapetus/` - Control plane
  - `cluster01/` - Production workloads
  - Each has `main.tf`, `variables.tf`, `terraform.tfvars` (gitignored)

- **`docker/`** - Custom Docker images (Atlantis only)

## Troubleshooting

### Container not starting

Check container logs:
```bash
incus info <container-name>
incus console <container-name>
```

### Service status (Alpine containers)

```bash
incus exec <container-name> -- rc-service <service-name> status
```

### OpenTofu state issues

View current state:
```bash
cd environments/iapetus  # or environments/cluster01
tofu show
```

### Network connectivity

Test internal DNS:
```bash
incus exec grafana01 -- ping prometheus01.incus
```

### Cross-environment connectivity

Ensure the cluster is accessible from iapetus:
```bash
# On iapetus or management host
incus remote list
incus list cluster01:
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for comprehensive troubleshooting guidance.

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
- [SECURITY.md](SECURITY.md) - Security architecture and controls
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [modules/*/README.md](modules/) - OpenTofu module documentation
