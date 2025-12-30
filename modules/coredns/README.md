# CoreDNS Terraform Module

This module deploys CoreDNS as a split-horizon DNS server for internal service resolution.

## Features

- **Authoritative Zone**: Serves DNS records for internal domain
- **Incus DNS Forwarding**: Resolves `.incus` queries via Incus DNS
- **Upstream Forwarding**: External queries forwarded to Cloudflare/Google DNS
- **Terraform Integration**: Zone records generated from service module outputs
- **External Access**: Proxy devices or OVN load balancer support

## Usage

```hcl
module "coredns01" {
  source = "../../modules/coredns"

  instance_name = "coredns01"
  profile_name  = "coredns"

  profiles = [
    module.base.container_base_profile.name,
    module.base.production_network_profile.name,
  ]

  # Zone configuration
  domain        = "example.com"
  nameserver_ip = "10.10.0.53"

  # DNS records from service modules
  dns_records = [
    { name = "grafana", type = "A", value = "10.20.0.10" },
    { name = "mqtt",    type = "A", value = "10.10.0.20" },
  ]

  # Forwarding
  incus_dns_server     = "10.20.0.1"
  upstream_dns_servers = ["1.1.1.1", "1.0.0.1"]
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CoreDNS Container                         │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                  CoreDNS Server                       │  │
│   │                                                       │  │
│   │   /etc/coredns/Corefile    (main config)             │  │
│   │   /etc/coredns/db.zone     (zone file)               │  │
│   │                                                       │  │
│   │   :53/udp,tcp  ───► DNS queries                      │  │
│   │   :8080/health ───► Health check                     │  │
│   │   :9153/metrics───► Prometheus metrics               │  │
│   └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Query Routing                            │  │
│   │   example.com  ───► Local zone file                  │  │
│   │   *.incus      ───► Incus DNS (10.20.0.1)           │  │
│   │   *            ───► Upstream (1.1.1.1, 1.0.0.1)     │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Static IP Assignment

For predictable DNS server addresses:

```hcl
module "coredns01" {
  # ...
  ipv4_address = "10.10.0.53"
  ipv4_gateway = "10.10.0.1"
}
```

### Additional Static Records

Add records not managed by service modules:

```hcl
module "coredns01" {
  # ...
  additional_records = [
    { name = "nas",     type = "A",     value = "192.168.1.100" },
    { name = "printer", type = "A",     value = "192.168.1.50" },
    { name = "www",     type = "CNAME", value = "grafana.example.com." },
  ]
}
```

### OVN Load Balancer

For OVN deployments, disable proxy devices and use OVN LB:

```hcl
module "coredns01" {
  # ...
  enable_external_access = false
  use_ovn_lb             = true
}

module "coredns_lb" {
  source = "../../modules/ovn-load-balancer"

  network_name   = module.base.production_network.name
  listen_address = "192.168.68.11"
  # ...
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the CoreDNS instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `domain` | Primary zone domain | `string` | n/a | yes |
| `nameserver_ip` | IP for NS record | `string` | n/a | yes |
| `profiles` | List of Incus profiles | `list(string)` | `[]` | no |
| `image` | Container image | `string` | `"images:alpine/3.21/cloud"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit | `string` | `"128MB"` | no |
| `storage_pool` | Storage pool | `string` | `"local"` | no |
| `root_disk_size` | Root disk size | `string` | `"1GB"` | no |
| `ipv4_address` | Static IPv4 (optional) | `string` | `""` | no |
| `ipv4_gateway` | Gateway for static IP | `string` | `""` | no |
| `dns_port` | DNS port | `string` | `"53"` | no |
| `health_port` | Health check port | `string` | `"8080"` | no |
| `dns_records` | Zone records | `list(object)` | `[]` | no |
| `additional_records` | Extra static records | `list(object)` | `[]` | no |
| `incus_dns_server` | Incus DNS server IP | `string` | `"10.20.0.1"` | no |
| `upstream_dns_servers` | Upstream DNS servers | `list(string)` | `["1.1.1.1", "1.0.0.1"]` | no |
| `enable_external_access` | Enable proxy devices | `bool` | `true` | no |
| `use_ovn_lb` | Use OVN load balancer | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `dns_endpoint` | DNS server endpoint |
| `ipv4_address` | Container IPv4 address |
| `health_endpoint` | Health check URL |
| `metrics_endpoint` | Prometheus metrics URL |

## Troubleshooting

### Check CoreDNS status

```bash
incus exec coredns01 -- rc-service coredns status
```

### Test DNS resolution

```bash
# Query the authoritative zone
dig @coredns01.incus grafana.example.com

# Query .incus resolution
dig @coredns01.incus prometheus01.incus

# Query external domain
dig @coredns01.incus google.com
```

### View configuration

```bash
incus exec coredns01 -- cat /etc/coredns/Corefile
incus exec coredns01 -- cat /etc/coredns/db.zone
```

### Check metrics

```bash
curl http://coredns01.incus:9153/metrics | grep coredns_dns_requests_total
```

## Related Modules

- [base-infrastructure](../base-infrastructure/) - Provides base profiles
- [ovn-load-balancer](../ovn-load-balancer/) - OVN LB for external access
- [mosquitto](../mosquitto/) - Service using CoreDNS

## References

- [CoreDNS Manual](https://coredns.io/manual/toc/)
- [CoreDNS Plugins](https://coredns.io/plugins/)
- [File Plugin](https://coredns.io/plugins/file/) - Zone file format
