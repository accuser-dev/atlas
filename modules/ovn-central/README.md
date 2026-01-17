# OVN Central Terraform Module

This module deploys OVN Central (northbound and southbound databases) as a container for Incus OVN networking.

## Features

- **Debian Trixie**: Uses Debian Trixie system container with systemd
- **OVN Databases**: Northbound and southbound OVSDB servers
- **Container-Based**: Runs on non-OVN network (incusbr0 or OVN management network)
- **Proxy Devices**: Exposes ports on physical network for chassis connections
- **Persistent Storage**: Database state survives restarts
- **Cluster Support**: Pin to specific node in clusters
- **Systemd Integration**: Proper service management with automatic stale lock cleanup
- **SSL/TLS Support**: Optional encrypted connections for OVN databases

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

After deploying the container, configure IncusOS nodes as OVN chassis.

**Automated (Recommended):**

```bash
# Configure all cluster nodes automatically
make configure-ovn-chassis ENV=cluster01

# Verify chassis registration
make verify-ovn-chassis ENV=cluster01
```

The Makefile targets automatically:
- Read the southbound connection from Terraform outputs
- Discover all cluster nodes and their IPs
- Configure each node with the correct tunnel address

**Manual (Reference):**

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

# Configure Incus to use OVN northbound (handled by ovn-config module)
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

### SSL/TLS Configuration

Enable encrypted connections for OVN databases:

```hcl
module "ovn_central" {
  source = "../../modules/ovn-central"

  # ... other configuration ...

  # Enable SSL
  enable_ssl  = true
  ssl_ca_cert = file("${path.module}/certs/ca.pem")
  ssl_cert    = file("${path.module}/certs/ovn-central.pem")
  ssl_key     = file("${path.module}/certs/ovn-central-key.pem")
}
```

When SSL is enabled:
- OVN databases listen on `pssl:` instead of `ptcp:`
- Connection strings use `ssl:` protocol (e.g., `ssl:192.168.71.5:6641`)
- Certificates are written to `/etc/ovn/` in the container
- Clients must present valid certificates to connect

**Certificate Requirements:**
- CA certificate (`ssl_ca_cert`): Used to verify client certificates
- Server certificate (`ssl_cert`): Must have the host address as SAN
- Server key (`ssl_key`): Private key for the server certificate

**Integration with step-ca:**

Generate certificates using your internal CA:

```bash
# Generate OVN central certificate
step ca certificate ovn-central.local \
  ovn-central.pem ovn-central-key.pem \
  --san 192.168.71.5 \
  --not-after 8760h

# Get CA certificate
step ca root ca.pem
```

**Configuring Incus for SSL:**

When using the `ovn-config` module with SSL:

```hcl
module "ovn_config" {
  source = "../../modules/ovn-config"

  northbound_connection = module.ovn_central[0].northbound_connection
  ca_cert               = module.ovn_central[0].ssl_ca_cert
  client_cert           = file("${path.module}/certs/incus-client.pem")
  client_key            = file("${path.module}/certs/incus-client-key.pem")
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the OVN Central instance | `string` | `"ovn-central01"` | no |
| `profile_name` | Name of the Incus profile | `string` | `"ovn-central"` | no |
| `host_address` | Physical network IP for proxy devices | `string` | n/a | yes |
| `profiles` | List of Incus profiles | `list(string)` | `[]` | no |
| `network_name` | Non-OVN network name | `string` | `"incusbr0"` | no |
| `image` | Container image | `string` | `"images:debian/trixie/cloud"` | no |
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
| `enable_ssl` | Enable SSL/TLS for database connections | `bool` | `false` | no |
| `ssl_ca_cert` | CA certificate (PEM format) | `string` | `""` | no |
| `ssl_cert` | Server certificate (PEM format) | `string` | `""` | no |
| `ssl_key` | Server private key (PEM format) | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `northbound_connection` | Northbound connection string (`tcp:` or `ssl:` based on config) |
| `southbound_connection` | Southbound connection string (`tcp:` or `ssl:` based on config) |
| `ssl_enabled` | Whether SSL is enabled |
| `ssl_ca_cert` | CA certificate for client configuration (sensitive) |

## Troubleshooting

### Check systemd service status

```bash
incus exec ovn-central01 -- systemctl status ovn-northd ovn-northd-db ovn-southd-db
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
incus exec ovn-central01 -- journalctl -u ovn-northd --no-pager -n 50
incus exec ovn-central01 -- journalctl -u ovn-northd-db --no-pager -n 50
incus exec ovn-central01 -- journalctl -u ovn-southd-db --no-pager -n 50
```

### Restart services

```bash
incus exec ovn-central01 -- systemctl restart ovn-northd-db ovn-southd-db ovn-northd
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
