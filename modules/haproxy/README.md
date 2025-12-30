# HAProxy Terraform Module

This module deploys HAProxy as a TCP/HTTP load balancer for Incus clusters.

## Features

- **TCP/HTTP Load Balancing**: Round-robin, least connections, etc.
- **Health Checks**: Automatic backend health monitoring
- **Stats Interface**: Web-based statistics dashboard
- **Static IP Support**: Predictable addressing for cluster VIPs
- **Flexible Configuration**: Declarative frontend/backend definitions

## Usage

```hcl
module "haproxy01" {
  source = "../../modules/haproxy"

  instance_name = "haproxy01"
  profile_name  = "haproxy"

  profiles = [
    module.base.container_base_profile.name,
    module.base.production_network_profile.name,
  ]

  # Static IP for VIP
  ipv4_address = "10.10.0.10"
  network_name = module.base.production_network.name

  # Stats interface
  stats_port     = 8404
  stats_user     = "admin"
  stats_password = var.haproxy_stats_password

  # Frontend configuration
  frontends = [
    {
      name            = "incus-api"
      bind_port       = 8443
      mode            = "tcp"
      default_backend = "incus-cluster"
    }
  ]

  # Backend configuration
  backends = [
    {
      name    = "incus-cluster"
      mode    = "tcp"
      balance = "roundrobin"
      servers = [
        { name = "node1", address = "192.168.71.2", port = 8443 },
        { name = "node2", address = "192.168.71.5", port = 8443 },
        { name = "node3", address = "192.168.71.8", port = 8443 },
      ]
    }
  ]
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    HAProxy Container                         │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                  HAProxy Server                       │  │
│   │                                                       │  │
│   │   /etc/haproxy/haproxy.cfg  (main config)            │  │
│   │                                                       │  │
│   │   :8443       ───► Frontend (TCP/HTTP)               │  │
│   │   :8404/stats ───► Stats dashboard                   │  │
│   └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Backend Servers                          │  │
│   │   node1:8443 ◄──── health check ────► active         │  │
│   │   node2:8443 ◄──── health check ────► active         │  │
│   │   node3:8443 ◄──── health check ────► active         │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Incus Cluster Load Balancing

Common configuration for IncusOS 3-node clusters:

```hcl
module "haproxy01" {
  # ...
  frontends = [
    {
      name            = "incus-api"
      bind_port       = 8443
      mode            = "tcp"
      default_backend = "incus-nodes"
    }
  ]

  backends = [
    {
      name    = "incus-nodes"
      mode    = "tcp"
      balance = "roundrobin"
      options = ["option tcp-check"]
      servers = [
        { name = "node1", address = "192.168.71.2", port = 8443, options = "check" },
        { name = "node2", address = "192.168.71.5", port = 8443, options = "check" },
        { name = "node3", address = "192.168.71.8", port = 8443, options = "check" },
      ]
    }
  ]
}
```

### HTTP Mode with Health Checks

```hcl
backends = [
  {
    name    = "web-servers"
    mode    = "http"
    balance = "leastconn"
    options = ["option httpchk GET /health"]
    servers = [
      { name = "web1", address = "10.20.0.10", port = 8080, options = "check" },
      { name = "web2", address = "10.20.0.11", port = 8080, options = "check" },
    ]
  }
]
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the HAProxy instance | `string` | `"haproxy01"` | no |
| `profile_name` | Name of the Incus profile | `string` | `"haproxy"` | no |
| `profiles` | List of Incus profiles | `list(string)` | `[]` | no |
| `image` | Container image | `string` | `"images:alpine/3.21/cloud"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit | `string` | `"256MB"` | no |
| `storage_pool` | Storage pool | `string` | `"local"` | no |
| `root_disk_size` | Root disk size | `string` | `"1GB"` | no |
| `ipv4_address` | Static IPv4 (optional) | `string` | `""` | no |
| `network_name` | Network for static IP | `string` | `""` | no |
| `stats_port` | Stats interface port | `number` | `8404` | no |
| `stats_user` | Stats username | `string` | `"admin"` | no |
| `stats_password` | Stats password (sensitive) | `string` | n/a | yes |
| `frontends` | Frontend configurations | `list(object)` | `[]` | no |
| `backends` | Backend configurations | `list(object)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `stats_url` | Stats dashboard URL |
| `ipv4_address` | Container IPv4 address |

## Troubleshooting

### Check HAProxy status

```bash
incus exec haproxy01 -- rc-service haproxy status
```

### View configuration

```bash
incus exec haproxy01 -- cat /etc/haproxy/haproxy.cfg
```

### Check backend health

```bash
# Via stats interface
curl -u admin:password http://haproxy01.incus:8404/stats

# Via HAProxy socket
incus exec haproxy01 -- echo "show servers state" | socat stdio /run/haproxy/admin.sock
```

### Test connectivity

```bash
# Test frontend
curl -k https://haproxy01.incus:8443

# Test individual backend
curl -k https://192.168.71.2:8443
```

## Related Modules

- [base-infrastructure](../base-infrastructure/) - Provides base profiles
- [ovn-central](../ovn-central/) - OVN databases (HAProxy can load balance)

## References

- [HAProxy Documentation](https://www.haproxy.org/documentation/)
- [HAProxy Configuration Manual](https://cbonte.github.io/haproxy-dconv/)
