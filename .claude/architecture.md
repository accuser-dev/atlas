# Architecture Details

Detailed architecture, design decisions, and technical patterns.

## Multi-Environment Architecture

### iapetus (Control Plane)

**Role**: Central control, monitoring aggregation, GitOps automation

**Services**:
- **Atlantis**: GitOps controller managing both environments via Incus remotes
- **Grafana**: Central dashboards visualizing metrics from all environments
- **Prometheus**: Federated setup pulling metrics from cluster01
- **Loki**: Aggregated log storage receiving logs via Alloy from cluster
- **Cloudflared**: Cloudflare Tunnel for secure external HTTP access
- **step-ca**: Internal ACME CA providing certificates for all environments

**Host**: Single IncusOS standalone host

### cluster01 (Production)

**Role**: Production workload hosting with high availability

**Services**:
- **Prometheus**: Local metrics collection, federated by iapetus
- **Alloy**: Log collection and shipping to iapetus Loki
- **Mosquitto**: MQTT broker for IoT/messaging
- **CoreDNS**: Split-horizon DNS server
- **Alertmanager**: Alert routing and notification

**Host**: 3-node IncusOS cluster with distributed storage

### Communication

- **Incus remotes**: Atlantis on iapetus manages cluster01 containers via remote connection
- **Prometheus federation**: iapetus pulls metrics from cluster01 Prometheus
- **Log shipping**: Alloy on cluster01 pushes logs to Loki on iapetus
- **Host metrics**: Scraped directly from IncusOS metrics API (no node-exporter needed)

## Network Architecture

### Network Segmentation

| Network | CIDR | Purpose | Access |
|---------|------|---------|--------|
| production | 10.10.0.0/24 | Public-facing services | External (via proxy/tunnel) |
| management | 10.20.0.0/24 | Monitoring, internal tools | Internal only |
| gitops | 10.30.0.0/24 | Atlantis automation | Internal only |

### Network Modes

**Bridge Mode** (NAT + proxy devices):
- Containers get private IPs from Incus managed bridge
- External access via Incus proxy devices or Cloudflare Tunnel
- Suitable for single-host deployments

**Physical Mode** (direct LAN attachment):
- Containers get IPs from physical LAN DHCP
- Direct network access without NAT
- Suitable for integration with existing network infrastructure

**OVN Mode** (overlay networking):
- Software-defined networking with microsegmentation
- Native OVN load balancers with LAN-routable VIPs
- Advanced features: ACLs, distributed routing, load balancing

## Container Architecture

### System Containers (Default)

**Base**: `images:debian/trixie/cloud`

**Characteristics**:
- Full systemd init
- Cloud-init for provisioning
- Package management (apt)
- Traditional service management
- Supports multiple processes

**Used by**: All services except Atlantis

**Provisioning**:
```hcl
config = {
  "cloud-init.user-data" = templatefile("${path.module}/cloud-init.yaml", {
    # Service-specific config
  })
}
```

### OCI Containers (Atlantis Only)

**Base**: Custom Docker images from `ghcr.io/accuser/atlas/atlantis`

**Characteristics**:
- Single process per container
- Immutable image-based deployment
- No init system
- Environment variable configuration

**Why only Atlantis**:
- Requires specific Terraform/OpenTofu versions
- Custom plugins and dependencies
- Frequent version updates
- Better suited to containerized workflow

## Profile Composition

Containers **never** use the default profile. Instead, they compose multiple profiles:

### Base Profiles (from base-infrastructure module)

1. **container_base_profile**: Core settings
   - `boot.autostart = true`
   - Security settings
   - Common limits

2. **Network profiles** (one per container):
   - `production_network_profile`
   - `management_network_profile`
   - `gitops_network_profile`

### Service-Specific Configuration

Applied directly to container resource:
- Root disk device
- CPU limits (`limits.cpu`)
- Memory limits (`limits.memory`)
- Storage volumes (when `enable_data_persistence = true`)
- Additional devices (proxy devices, etc.)

### Example

```hcl
profiles = [
  module.base.container_base_profile.name,
  module.base.management_network_profile.name,
]

devices = {
  root = { ... }        # Root filesystem
  data = { ... }        # Persistent storage volume
}

limits.cpu    = "2"
limits.memory = "2GiB"
```

## Storage Architecture

### Volume Management

Each module manages its own storage volume when persistence is enabled:

```hcl
enable_data_persistence = true
data_volume_size        = "10GiB"
```

**Storage pool**: Shared ZFS or btrfs pool on IncusOS host

**Volumes**: Separate volume per service mounted at service-specific path

### Snapshot Strategy

Configurable per module:

```hcl
enable_snapshots        = true
snapshot_schedule       = "0 2 * * *"  # Daily at 2 AM
snapshot_name_pattern   = "snap%d"
snapshots_expiry        = "7d"         # Retain for 7 days
```

**Implementation**: Incus built-in snapshot scheduling (no external tools)

**Backup**: See [BACKUP.md](../BACKUP.md) for backup procedures

## External Access Patterns

### HTTP Services

**Primary**: Cloudflare Tunnel (Zero Trust)
- Runs on iapetus
- Provides ingress for Grafana, Prometheus, etc.
- Benefits: Zero Trust security, no open ports, automatic HTTPS

**Alternative**: Incus proxy device (bridge mode) or direct access (physical/OVN mode)

### TCP Services

**Bridge mode**: Incus proxy devices
```hcl
devices = {
  mqtt = {
    type   = "proxy"
    listen = "tcp:0.0.0.0:1883"
    connect = "tcp:127.0.0.1:1883"
  }
}
```

**Physical mode**: Direct container IP access

**OVN mode**: OVN load balancers with VIPs
```hcl
module "mosquitto_lb" {
  source = "../../modules/ovn-load-balancer"
  vip    = "10.10.0.100:1883"
  backends = [module.mosquitto.ip_address]
}
```

## Certificate Management

**Internal CA**: step-ca on iapetus

**ACME Support**: Provides ACME protocol for automatic certificate issuance

**Usage**:
- Services request certificates via ACME client (certbot, step-cli, etc.)
- Certificates automatically renewed before expiry
- Supports both HTTP-01 and DNS-01 challenges

**Integration**: Prometheus, Grafana, and other services can use step-ca certificates

## Monitoring Architecture

### Metrics Collection

**Tier 1 - Local Collection**:
- Prometheus on cluster01 scrapes local services
- Incus metrics API provides host-level metrics (CPU, memory, network, disk)
- Service exporters (if needed) expose application metrics

**Tier 2 - Federation**:
- Prometheus on iapetus federates from cluster01
- Aggregates metrics across all environments
- Long-term storage and retention

**Visualization**:
- Grafana on iapetus queries both Prometheus instances
- Centralized dashboards for all environments

### Log Aggregation

**Collection**:
- Alloy on cluster01 scrapes journald logs
- Filters and labels logs by service
- Ships to Loki on iapetus

**Storage**:
- Loki on iapetus stores aggregated logs
- Configurable retention periods
- Compressed and indexed for efficient queries

**Querying**:
- Grafana Explore interface
- LogQL query language
- Correlation with metrics via exemplars

### Incus Native Logging

**Direct Incus → Loki**:
- incus-loki module configures Incus daemon to ship events directly
- System-level events (container start/stop, config changes, etc.)
- Separate from application logs

## High Availability Considerations

### cluster01 (3-node cluster)

**Container placement**: Incus cluster automatically schedules containers across nodes

**Storage**: Distributed storage (Ceph) provides redundancy

**Failover**: Containers automatically migrate on node failure (if HA is enabled)

### iapetus (single host)

**No HA**: Single point of failure for control plane

**Mitigation**:
- cluster01 continues running if iapetus is down
- Local Prometheus on cluster01 maintains metrics collection
- Manual intervention required to restore control plane

**Future**: Could migrate to Incus cluster for iapetus HA

## GitOps Workflow

**Controller**: Atlantis on iapetus

**Operation**:
1. Developer opens PR on GitHub
2. Atlantis webhook receives notification
3. Atlantis runs `tofu plan` automatically
4. Plan posted as PR comment
5. On approval and merge, Atlantis runs `tofu apply`
6. Infrastructure changes applied to both environments

**Remote Management**:
- Atlantis connects to cluster01 via Incus remote
- Single Atlantis instance manages multiple environments
- Separate Terraform workspaces per environment

## Hybrid Provisioning Pattern

This project uses a hybrid approach combining Terraform for infrastructure provisioning and Ansible for configuration management. This pattern separates concerns clearly and enables independent day-2 operations.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Terraform + Cloud-Init                                      │
│ • Container lifecycle (create/destroy)                      │
│ • Storage volumes                                           │
│ • Network configuration                                     │
│ • Profile assignment                                        │
│ • Minimal bootstrap (Python3 for Ansible)                   │
└────────────────────────┬────────────────────────────────────┘
                         │ Outputs: instance_info, ansible_vars
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Dynamic Inventory (ansible/inventory/terraform.py)         │
│ • Reads `tofu output -json`                                 │
│ • Maps instances to Ansible groups                          │
│ • Injects Terraform variables into Ansible                  │
└────────────────────────┬────────────────────────────────────┘
                         │ Groups + hostvars
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Ansible                                                     │
│ • Binary installation and updates                           │
│ • Configuration file management                             │
│ • Service registration (idempotent)                         │
│ • Systemd service lifecycle                                 │
│ • Day-2 operations (upgrades, config changes)               │
└─────────────────────────────────────────────────────────────┘
```

### Responsibility Separation

| Concern | Terraform | Ansible |
|---------|-----------|---------|
| Container creation/destruction | ✅ | |
| Storage volumes | ✅ | |
| Network attachment | ✅ | |
| Resource limits (CPU/memory) | ✅ | |
| Base OS packages (Python3) | ✅ (cloud-init) | |
| Application binaries | | ✅ |
| Configuration files | | ✅ |
| Service registration | | ✅ |
| Systemd service management | | ✅ |
| Version upgrades | | ✅ |

### Cloud-Init: Minimal Bootstrap Only

Cloud-init is intentionally minimal—just enough to enable Ansible:

```yaml
#cloud-config
packages:
  - python3
  - python3-apt
```

**Why minimal?**
- Keeps Terraform state simple (no application config stored)
- Allows Ansible to manage all application concerns
- Cloud-init runs only once; Ansible is idempotent and repeatable
- Version upgrades don't require Terraform changes

### Dynamic Inventory

The inventory script (`ansible/inventory/terraform.py`) bridges Terraform and Ansible:

```bash
# How it works
cd environments/${ENV}
tofu output -json
```

**Output mapping:**
- `*_instances` outputs → Ansible host lists
- `*_ansible_vars` outputs → Ansible group variables

**Example Terraform outputs:**
```hcl
output "forgejo_runner_instances" {
  value = [for r in module.forgejo_runner : r.instance_name]
}

output "forgejo_runner_ansible_vars" {
  value = {
    forgejo_url    = var.forgejo_url
    runner_labels  = var.forgejo_runner_labels
    runner_version = var.forgejo_runner_version
  }
}
```

### Ansible Connection via Incus

Ansible connects directly to containers via the Incus socket—no SSH required:

```yaml
# group_vars
ansible_connection: community.general.incus
ansible_incus_remote: cluster01
```

**Benefits:**
- No SSH keys to manage
- No network access required to containers
- Uses existing Incus authentication
- Works with unprivileged containers

### Idempotent Operations

Ansible roles must be idempotent (safe to re-run):

```yaml
# Example: Skip registration if already registered
- name: Check if runner is registered
  stat:
    path: /etc/forgejo-runner/.runner
  register: runner_file

- name: Register runner
  command: forgejo-runner register ...
  when: not runner_file.stat.exists
```

### Facts Caching

Ansible facts are cached to improve performance:

```ini
# ansible.cfg
[defaults]
gathering = smart
fact_caching = jsonfile
fact_caching_connection = .ansible_cache
fact_caching_timeout = 86400
```

**Benefits:**
- Subsequent playbook runs skip fact gathering
- Faster iteration during development
- Cache persists across sessions

### Workflow

**Initial deployment:**
```bash
# 1. Provision infrastructure
make apply ENV=cluster01

# 2. One-time Ansible setup
make ansible-setup

# 3. Configure application (may require secrets)
FORGEJO_RUNNER_TOKEN=<token> make configure-runner-register ENV=cluster01
```

**Day-2 operations (no Terraform needed):**
```bash
# Update configuration
make configure-runner ENV=cluster01

# Upgrade version (change version in variables, re-run Ansible)
# Ansible detects version mismatch and downloads new binary
```

### Module Implementation Pattern

When creating a new module following this pattern:

**1. Terraform module outputs:**
```hcl
output "instance_name" {
  value = incus_instance.this.name
}

output "ansible_vars" {
  value = {
    service_version = var.version
    service_config  = var.config_option
  }
}
```

**2. Environment outputs (aggregated):**
```hcl
output "service_instances" {
  value = [for s in module.service : s.instance_name]
}

output "service_ansible_vars" {
  value = length(module.service) > 0 ? module.service[0].ansible_vars : {}
}
```

**3. Ansible role structure:**
```
roles/service_name/
├── defaults/main.yml      # Default variables
├── tasks/
│   ├── main.yml          # Entry point
│   ├── install.yml       # Binary/package installation
│   ├── configure.yml     # Config file templating
│   └── service.yml       # Systemd setup
├── templates/
│   ├── config.j2         # Service configuration
│   └── service.service.j2
└── handlers/main.yml     # Restart handlers
```

**4. Makefile targets:**
```makefile
configure-service:
	cd ansible && ansible-playbook playbooks/service.yml
```

### Reference Implementation

The Forgejo Runner module demonstrates this pattern completely:

- **Terraform**: `modules/forgejo-runner/`
- **Ansible role**: `ansible/roles/forgejo_runner/`
- **Playbook**: `ansible/playbooks/forgejo-runner.yml`
- **Inventory**: `ansible/inventory/terraform.py`
- **Makefile**: targets `configure-runner` and `configure-runner-register`

## Design Decisions

### Why system containers over OCI?

- Full systemd support for complex services
- Better suited for multi-process applications
- Native package management
- Consistent with traditional VM-to-container migration path
- Easier debugging and troubleshooting

### Why separate environments?

- Isolation between control plane and workloads
- Independent scaling and maintenance
- Blast radius containment
- Flexibility in deployment models (single host vs. cluster)

### Why Incus over Kubernetes?

- Lower resource overhead
- Simpler operations
- Better suited for traditional applications
- Native VM support when needed
- Unified container and VM management

### Why centralized vs. distributed monitoring?

- Single pane of glass for observability
- Simplified dashboard management
- Long-term metric retention on control plane
- Local Prometheus ensures availability during outages

### Why Terraform + Ansible hybrid over pure Terraform?

- **Separation of concerns**: Infrastructure (Terraform) vs. configuration (Ansible)
- **Simpler Terraform state**: No application config, secrets, or service state
- **Independent day-2 ops**: Version upgrades and config changes without Terraform
- **Idempotent configuration**: Ansible can safely re-run; cloud-init runs only once
- **Better secret handling**: Ansible can use environment variables at runtime
- **Existing tooling**: Ansible has mature roles for common services
- **Debugging**: Easier to troubleshoot configuration vs. infrastructure issues separately
