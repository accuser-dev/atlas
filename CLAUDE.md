# CLAUDE.md

Guidance for Claude Code when working with this repository.

## Project Overview

Multi-environment Terraform infrastructure managing Incus containers across multiple hosts:
- **iapetus**: Control plane with GitOps, monitoring aggregation, and central CA
- **cluster01**: 3-node production cluster with distributed workloads

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ iapetus (Control Plane)                                     │
│ Atlantis, Grafana, Prometheus, Loki, Cloudflared, step-ca  │
└────────────────────┬────────────────────────────────────────┘
                     │ remote Incus + federation
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ cluster01 (Production - 3 nodes)                            │
│ Prometheus, Alloy, Mosquitto, CoreDNS, Alertmanager        │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
atlas/
├── modules/              # Reusable Terraform modules (each has README.md)
├── environments/
│   ├── iapetus/         # Control plane config
│   └── cluster01/       # Production cluster config
├── docker/atlantis/     # Custom Atlantis OCI image
├── .claude/             # Extended context (load as needed)
└── .github/workflows/   # CI/CD
```

## Critical Rules

- **Never run `tofu init` directly** - always use `make init` (handles remote state)
- **System containers by default** - Debian Trixie with cloud-init/systemd (`images:debian/trixie/cloud`)
- **OCI containers only for Atlantis** - uses `ghcr.io` images
- **No default profile** - containers use layered profiles from base-infrastructure module
- **terraform.tfvars is gitignored** - contains secrets, create manually per environment
- **Use feature branches** - GitHub Flow, all PRs to `main`

## Key Patterns

**Storage**: Modules manage their own volumes when `enable_data_persistence = true`

**Networks**:
- `production` (10.10.0.0/24) - public services
- `management` (10.20.0.0/24) - internal monitoring
- `gitops` (10.30.0.0/24) - automation

**Profiles**: Containers layer base profiles + service-specific config (disk, limits, volumes)

**External access**: Cloudflare Tunnel for HTTP, proxy devices or OVN LB for TCP

## Quick Start

```bash
# iapetus (default)
make plan
make apply

# cluster01
ENV=cluster01 make plan
ENV=cluster01 make apply
```

## Extended Context

Load these when working on specific areas:

- [.claude/commands.md](.claude/commands.md) - Complete command reference
- [.claude/development.md](.claude/development.md) - Development workflow and CI/CD
- [.claude/architecture.md](.claude/architecture.md) - Detailed architecture and design decisions

Module documentation: Each `modules/*/README.md` has detailed usage, variables, and troubleshooting.
