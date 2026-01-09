# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

Multi-environment Terraform infrastructure project managing Incus containers across multiple hosts:

- **`iapetus`** - Control plane / aggregation (IncusOS standalone host)
- **`cluster01`** - Production workloads (3-node IncusOS cluster)

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         iapetus (IncusOS)                           │
│                    Control Plane / Aggregation                      │
├─────────────────────────────────────────────────────────────────────┤
│  - Atlantis (GitOps) → manages iapetus + cluster via remote Incus   │
│  - Grafana (central dashboards)                                     │
│  - Prometheus (federated, pulls from cluster)                       │
│  - Loki (aggregated logs via Alloy on cluster)                      │
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
│  - Alloy → ships logs to iapetus Loki                               │
│  - Host metrics scraped from IncusOS nodes (no node-exporter)       │
│  - Mosquitto, CoreDNS, Alertmanager                                 │
└─────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
atlas/
├── modules/                   # Shared Terraform modules (see individual READMEs)
│   ├── alertmanager/          # Alert routing and notifications
│   ├── alloy/                 # Log collection and shipping
│   ├── atlantis/              # GitOps controller
│   ├── base-infrastructure/   # Networks and base profiles
│   ├── cloudflared/           # Cloudflare Tunnel client
│   ├── coredns/               # Split-horizon DNS
│   ├── dex/                   # OIDC identity provider
│   ├── grafana/               # Visualization platform
│   ├── haproxy/               # TCP/HTTP load balancer
│   ├── incus-loki/            # Native Incus → Loki logging
│   ├── incus-metrics/         # Incus metrics certificates
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
│   ├── iapetus/               # Control plane (main.tf, variables.tf, etc.)
│   └── cluster01/             # Production cluster
│
├── docker/                    # Custom Docker images (Atlantis only)
│   └── atlantis/
│
├── .github/workflows/         # CI/CD pipelines
├── Makefile                   # ENV=iapetus make plan
├── BACKUP.md                  # Backup procedures
└── CONTRIBUTING.md            # Development workflow
```

## Common Commands

### Makefile Operations

```bash
# Bootstrap (first-time setup)
make bootstrap                    # iapetus
ENV=cluster01 make bootstrap      # cluster01

# OpenTofu operations
make init                         # Initialize
make plan                         # Plan changes
make apply                        # Apply changes
make destroy                      # Destroy infrastructure

# Target cluster01
ENV=cluster01 make plan
ENV=cluster01 make apply

# Utilities
make format                       # Format .tf files
make clean                        # Clean build artifacts
make backup-snapshot              # Snapshot all volumes
```

### Direct OpenTofu

```bash
cd environments/iapetus  # or cluster01
tofu validate
tofu plan
tofu apply
tofu output
```

## Key Design Patterns

### Container Types

- **System containers** (most services): Debian Trixie + cloud-init + systemd (`images:debian/trixie/cloud`)
- **OCI containers** (Atlantis only): Docker images from `ghcr.io`

### Network Architecture

| Network | CIDR | Purpose |
|---------|------|---------|
| production | 10.10.0.0/24 | Public-facing services |
| management | 10.20.0.0/24 | Internal services (monitoring) |
| gitops | 10.30.0.0/24 | GitOps automation (optional) |

Production network supports bridge mode (NAT + proxy devices) or physical mode (direct LAN attachment).

### Profile Composition

Containers use layered profiles (no default profile):

```hcl
profiles = [
  module.base.container_base_profile.name,     # boot.autorestart
  module.base.management_network_profile.name, # Network NIC
]
# Service module adds: root disk, CPU/memory limits, storage volumes
```

### External Access

- **HTTP services**: Cloudflare Tunnel (Zero Trust)
- **TCP services**: Incus proxy devices (bridge mode) or direct LAN (physical mode)
- **OVN mode**: Native load balancers with LAN-routable VIPs

### Storage

Each service module manages its own storage volume when `enable_data_persistence = true`. Volumes support automatic snapshots via `enable_snapshots = true`.

## Terraform State

Each environment uses S3-compatible Incus storage bucket for remote state:

```bash
# Bootstrap creates the bucket
make bootstrap

# Initialize with remote backend
make init

# Normal operations
make plan
make apply
```

Never run `tofu init` directly - use `make init` or `./init.sh`.

## Development Workflow

Uses GitHub Flow - all work on feature branches merged to `main`.

```bash
git checkout -b feature/description
# Make changes
git commit -m "fix: description"
git push -u origin feature/description
gh pr create --base main
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Module Documentation

Each module has its own README.md with:
- Features and usage examples
- Architecture diagrams
- Variables and outputs reference
- Troubleshooting guide

Key modules:
- [base-infrastructure](modules/base-infrastructure/README.md) - Networks and profiles
- [prometheus](modules/prometheus/README.md) - Metrics with retention, alerts, Incus metrics
- [grafana](modules/grafana/README.md) - Dashboards with security headers
- [loki](modules/loki/README.md) - Log aggregation with retention
- [step-ca](modules/step-ca/README.md) - Internal ACME CA

## Outputs

After applying, view endpoints:

```bash
cd environments/iapetus && tofu output
```

**iapetus**: `loki_endpoint`, `prometheus_endpoint`, `step_ca_acme_endpoint`, `cloudflared_metrics_endpoint`

**cluster01**: `prometheus_endpoint`, `alertmanager_endpoint`, `mosquitto_mqtt_endpoint`, `coredns_dns_endpoint`

## Important Notes

- `terraform.tfvars` files are gitignored - create manually with secrets
- Most services use Debian Trixie system containers with systemd, only Atlantis uses OCI
- OCI images auto-built by GitHub Actions on push to main
- Use `incus exec <container> -- systemctl status <service>` for service checks
- Use `incus exec <container> -- journalctl -u <service>` for logs
