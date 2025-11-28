# Base Infrastructure Terraform Module

This module provides the foundational infrastructure for all Atlas services, including networks and reusable Incus profiles.

## Features

- **Five Environment Networks**: Development, Testing, Staging, Production, Management
- **Docker Base Profile**: Root disk and auto-restart configuration
- **Network Profiles**: Semantic NIC devices for each network (prod, mgmt, dev, test, stage)
- **IPv4 and IPv6 Support**: Optional dual-stack networking
- **NAT Configuration**: Configurable NAT for each network
- **Profile Composition**: Enables service modules to compose base + service profiles

## Usage

```hcl
module "base" {
  source = "./modules/base-infrastructure"

  storage_pool = "local"

  # Network configuration (defaults shown)
  development_network_ipv4 = "10.10.0.1/24"
  testing_network_ipv4     = "10.20.0.1/24"
  staging_network_ipv4     = "10.30.0.1/24"
  production_network_ipv4  = "10.40.0.1/24"
  management_network_ipv4  = "10.50.0.1/24"
}

# Use base profiles in service modules
module "grafana01" {
  source = "./modules/grafana"

  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.management_network_profile.name,
  ]
  # ...
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Base Infrastructure                       │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                    Networks                           │  │
│   │                                                       │  │
│   │   development  ─── 10.10.0.1/24 ─── Dev workloads    │  │
│   │   testing      ─── 10.20.0.1/24 ─── Test workloads   │  │
│   │   staging      ─── 10.30.0.1/24 ─── Staging workloads│  │
│   │   production   ─── 10.40.0.1/24 ─── Prod workloads   │  │
│   │   management   ─── 10.50.0.1/24 ─── Internal services│  │
│   │                                                       │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                    Profiles                           │  │
│   │                                                       │  │
│   │   docker-base ──────────────────────────────────────┐│  │
│   │   │  boot.autorestart = true                        ││  │
│   │   │  root disk on storage pool                      ││  │
│   │   └─────────────────────────────────────────────────┘│  │
│   │                                                       │  │
│   │   *-network ────────────────────────────────────────┐│  │
│   │   │  Semantic NIC device (prod, mgmt, dev, etc.)    ││  │
│   │   │  (one profile per network)                      ││  │
│   │   └─────────────────────────────────────────────────┘│  │
│   │                                                       │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Profile Composition Pattern

Service modules use profile composition to inherit base infrastructure:

```hcl
# Service module receives base profiles via var.profiles
profiles = concat(var.profiles, [incus_profile.service.name])

# Results in ordered profiles:
# 1. "default"                 - Incus default profile
# 2. "docker-base"             - Root disk + auto-restart
# 3. "management-network"      - mgmt NIC on management network
# 4. "grafana" (service-specific) - CPU/memory limits, data volume
```

**Profile order matters**: Later profiles override earlier ones. Service-specific profiles define resource limits and service devices, while base profiles provide infrastructure.

## Network Layout

| Network | IPv4 CIDR | Purpose |
|---------|-----------|---------|
| development | 10.10.0.1/24 | Development workloads |
| testing | 10.20.0.1/24 | Testing workloads |
| staging | 10.30.0.1/24 | Staging workloads |
| production | 10.40.0.1/24 | Production applications |
| management | 10.50.0.1/24 | Internal services (monitoring, CA, etc.) |

**Management Network Services:**
- Grafana, Prometheus, Loki (monitoring stack)
- step-ca (internal CA)
- Alertmanager
- Node Exporter
- Cloudflared (tunnel client)

## IPv6 Configuration

Enable IPv6 (dual-stack) by setting IPv6 addresses:

```hcl
module "base" {
  # ...
  development_network_ipv6 = "fd00:10:10::1/64"
  testing_network_ipv6     = "fd00:10:20::1/64"
  staging_network_ipv6     = "fd00:10:30::1/64"
  production_network_ipv6  = "fd00:10:40::1/64"
  management_network_ipv6  = "fd00:10:50::1/64"
}
```

**Notes:**
- IPv6 is disabled by default (empty string)
- Uses ULA (Unique Local Address) prefix `fd00::/8`
- NAT66 is configurable per network

## Variables

### Storage

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `storage_pool` | Storage pool for root disks | `string` | `"local"` |

### Development Network

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `development_network_ipv4` | IPv4 address (CIDR) | `string` | `"10.10.0.1/24"` |
| `development_network_nat` | Enable IPv4 NAT | `bool` | `true` |
| `development_network_ipv6` | IPv6 address (CIDR) | `string` | `""` |
| `development_network_ipv6_nat` | Enable IPv6 NAT | `bool` | `true` |

### Testing Network

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `testing_network_ipv4` | IPv4 address (CIDR) | `string` | `"10.20.0.1/24"` |
| `testing_network_nat` | Enable IPv4 NAT | `bool` | `true` |
| `testing_network_ipv6` | IPv6 address (CIDR) | `string` | `""` |
| `testing_network_ipv6_nat` | Enable IPv6 NAT | `bool` | `true` |

### Staging Network

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `staging_network_ipv4` | IPv4 address (CIDR) | `string` | `"10.30.0.1/24"` |
| `staging_network_nat` | Enable IPv4 NAT | `bool` | `true` |
| `staging_network_ipv6` | IPv6 address (CIDR) | `string` | `""` |
| `staging_network_ipv6_nat` | Enable IPv6 NAT | `bool` | `true` |

### Production Network

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `production_network_ipv4` | IPv4 address (CIDR) | `string` | `"10.40.0.1/24"` |
| `production_network_nat` | Enable IPv4 NAT | `bool` | `true` |
| `production_network_ipv6` | IPv6 address (CIDR) | `string` | `""` |
| `production_network_ipv6_nat` | Enable IPv6 NAT | `bool` | `true` |

### Management Network

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `management_network_ipv4` | IPv4 address (CIDR) | `string` | `"10.50.0.1/24"` |
| `management_network_nat` | Enable IPv4 NAT | `bool` | `true` |
| `management_network_ipv6` | IPv6 address (CIDR) | `string` | `""` |
| `management_network_ipv6_nat` | Enable IPv6 NAT | `bool` | `true` |

### External Network

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `external_network` | External network name | `string` | `"incusbr0"` |

## Outputs

### Networks

| Name | Description |
|------|-------------|
| `development_network` | Development network resource |
| `testing_network` | Testing network resource |
| `staging_network` | Staging network resource |
| `production_network` | Production network resource |
| `management_network` | Management network resource |
| `management_network_gateway` | Management network gateway IP (for Incus metrics) |
| `external_network` | External network name |

### Profiles

| Name | Description |
|------|-------------|
| `docker_base_profile` | Docker base profile (boot.autorestart, root disk) |
| `development_network_profile` | Development network profile (dev NIC) |
| `testing_network_profile` | Testing network profile (test NIC) |
| `staging_network_profile` | Staging network profile (stage NIC) |
| `production_network_profile` | Production network profile (prod NIC) |
| `management_network_profile` | Management network profile (mgmt NIC) |

## Troubleshooting

### List networks

```bash
incus network list
```

### View network configuration

```bash
incus network show management
```

### List profiles

```bash
incus profile list
```

### View profile configuration

```bash
incus profile show docker-base
incus profile show management-network
```

### Check container network

```bash
incus exec grafana01 -- ip addr
incus exec grafana01 -- ping prometheus01.incus
```

### Test cross-network connectivity

```bash
# From management network container
incus exec grafana01 -- ping caddy01.incus  # Should work if Caddy is on management
```

## Service Module Integration

Service modules should accept a `profiles` variable:

```hcl
# In service module's variables.tf
variable "profiles" {
  description = "List of Incus profile names to apply (should include base profiles)"
  type        = list(string)
  default     = ["default"]
}

# In service module's main.tf
resource "incus_instance" "service" {
  # ...
  profiles = concat(var.profiles, [incus_profile.service.name])
}
```

This pattern allows the root module to compose infrastructure:

```hcl
# In root main.tf
module "grafana01" {
  source = "./modules/grafana"

  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.management_network_profile.name,
  ]
}
```

## Related Modules

All service modules depend on base-infrastructure:

- [alertmanager](../alertmanager/)
- [caddy](../caddy/)
- [cloudflared](../cloudflared/)
- [grafana](../grafana/)
- [loki](../loki/)
- [mosquitto](../mosquitto/)
- [node-exporter](../node-exporter/)
- [prometheus](../prometheus/)
- [step-ca](../step-ca/)

## References

- [Incus Networks](https://linuxcontainers.org/incus/docs/main/networks/)
- [Incus Profiles](https://linuxcontainers.org/incus/docs/main/profiles/)
- [Profile Composition](https://linuxcontainers.org/incus/docs/main/profiles/#profile-stacking)
