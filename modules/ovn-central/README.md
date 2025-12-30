# OVN Central Terraform Module

This module deploys OVN Central (northbound and southbound databases) as a container for Incus OVN networking.

## Features

- **OVN Databases**: Northbound and southbound OVSDB servers
- **Container-Based**: Runs on non-OVN network (incusbr0)
- **Proxy Devices**: Exposes ports on physical network for chassis connections
- **Persistent Storage**: Database state survives restarts
- **Cluster Support**: Pin to specific node in clusters

## Usage

```hcl
module "ovn_central" {
  source = "../../modules/ovn-central"

  instance_name = "ovn-central01"
  profile_name  = "ovn-central"

  profiles = [
    module.base.container_base_profile.name,
  ]

  # Network (must be non-OVN)
  network_name = "incusbr0"
  host_address = "192.168.71.5"  # Physical node IP for proxy devices

  # Storage
  enable_data_persistence = true
  data_volume_name        = "ovn-central-data"
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  OVN Central Container                       │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              OVN Northbound Database                  │  │
│   │   /var/lib/ovn/ovnnb_db.db                           │  │
│   │   :6641 ───► Northbound OVSDB (Incus connects here)  │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              OVN Southbound Database                  │  │
│   │   /var/lib/ovn/ovnsb_db.db                           │  │
│   │   :6642 ───► Southbound OVSDB (chassis connect here) │  │
│   └──────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────┘
                           │ Proxy devices
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Physical Network                            │
│   192.168.71.5:6641 ───► OVN Northbound                     │
│   192.168.71.5:6642 ───► OVN Southbound                     │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  IncusOS Chassis Nodes                       │
│   node1 ───► ovn-controller → 192.168.71.5:6642            │
│   node2 ───► ovn-controller → 192.168.71.5:6642            │
│   node3 ───► ovn-controller → 192.168.71.5:6642            │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Post-Deployment Setup

After deploying the container, configure IncusOS nodes as OVN chassis:

```bash
# On each IncusOS node, configure OVN chassis
incus admin os service edit ovn --target=node1 << 'EOF'
{
  "config": {
    "database": "tcp:192.168.71.5:6642",
    "enabled": true,
    "tunnel_address": "192.168.71.2"
  }
}
EOF

# Configure Incus to use OVN northbound
incus config set network.ovn.northbound_connection=tcp:192.168.71.5:6641
```

### Cluster Deployment

Pin to a specific cluster node:

```hcl
module "ovn_central" {
  # ...
  target_node = "node1"
}
```

### High Availability (Future)

For HA, deploy multiple OVN Central containers and configure clustering:

```hcl
# This is a future enhancement - currently single-node only
# northbound_connection = "tcp:192.168.71.5:6641,tcp:192.168.71.2:6641,tcp:192.168.71.8:6641"
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the OVN Central instance | `string` | `"ovn-central01"` | no |
| `profile_name` | Name of the Incus profile | `string` | `"ovn-central"` | no |
| `host_address` | Physical network IP for proxy devices | `string` | n/a | yes |
| `profiles` | List of Incus profiles | `list(string)` | `[]` | no |
| `network_name` | Non-OVN network name | `string` | `"incusbr0"` | no |
| `image` | Container image | `string` | `"images:alpine/3.21/cloud"` | no |
| `target_node` | Target cluster node | `string` | `""` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit | `string` | `"512MB"` | no |
| `root_disk_size` | Root disk size | `string` | `"1GB"` | no |
| `storage_pool` | Storage pool | `string` | `"local"` | no |
| `enable_data_persistence` | Enable persistent storage | `bool` | `true` | no |
| `data_volume_name` | Data volume name | `string` | `"ovn-central-data"` | no |
| `data_volume_size` | Data volume size | `string` | `"1GB"` | no |
| `northbound_port` | Northbound DB port | `number` | `6641` | no |
| `southbound_port` | Southbound DB port | `number` | `6642` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `northbound_connection` | Northbound connection string |
| `southbound_connection` | Southbound connection string |

## Troubleshooting

### Check OVN services

```bash
incus exec ovn-central01 -- rc-service ovn-northd status
incus exec ovn-central01 -- rc-service ovn-sb-ovsdb status
incus exec ovn-central01 -- rc-service ovn-nb-ovsdb status
```

### Verify databases

```bash
# List logical switches
incus exec ovn-central01 -- ovn-nbctl show

# List chassis
incus exec ovn-central01 -- ovn-sbctl show
```

### Check connectivity from chassis

```bash
# From an IncusOS node
ovs-vsctl get open_vswitch . external_ids:ovn-remote
ovn-sbctl --db=tcp:192.168.71.5:6642 show
```

### View logs

```bash
incus exec ovn-central01 -- cat /var/log/ovn/ovn-northd.log
```

## Related Modules

- [ovn-config](../ovn-config/) - Configure Incus OVN settings
- [ovn-load-balancer](../ovn-load-balancer/) - OVN load balancers
- [base-infrastructure](../base-infrastructure/) - Provides base profiles
- [haproxy](../haproxy/) - Alternative: HAProxy for non-OVN load balancing

## References

- [OVN Architecture](https://docs.ovn.org/en/latest/ref/ovn-architecture.7.html)
- [Incus OVN Networks](https://linuxcontainers.org/incus/docs/main/reference/network_ovn/)
- [IncusOS OVN Setup](https://linuxcontainers.org/incus/docs/main/howto/network_ovn_setup/)
