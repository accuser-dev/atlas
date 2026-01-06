# Incus Network Zone Module

Creates an Incus network zone for automatic DNS registration of containers. This module enables containers to be automatically registered in DNS as `<container>.<zone>`.

## Features

- Automatic A/AAAA record creation for containers
- Gateway records for networks (`<network>.gw.<zone>`)
- Zone transfer (AXFR) support for external DNS servers
- Custom record support for manual entries
- Multi-environment support via peer configuration

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Incus Network Zone                                │
│                    (incus.accuser.dev)                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Automatic Records:                                                  │
│    grafana01.incus.accuser.dev    → 10.20.0.10                      │
│    prometheus01.incus.accuser.dev → 10.20.0.11                      │
│    management.gw.incus.accuser.dev → 10.20.0.1                      │
│                                                                      │
│  Custom Records:                                                     │
│    api.incus.accuser.dev CNAME grafana01.incus.accuser.dev          │
│                                                                      │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ AXFR zone transfer
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    CoreDNS (Secondary Zone)                          │
│                    Serves authoritative responses                    │
└─────────────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage (with OVN)

For OVN environments, you need:
1. `dns_listen_address` - Where Incus binds (use `:5353` for all interfaces)
2. `dns_reachable_address` - Where CoreDNS connects (host's LAN IP)
3. `transfer_peers` - Source IP the host sees for zone transfer requests (OVN NAT IP)

```hcl
module "network_zone" {
  source = "../../modules/incus-network-zone"

  zone_name   = "incus.accuser.dev"
  description = "Container DNS zone"

  # Bind to all interfaces on the host
  dns_listen_address    = ":5353"

  # Address CoreDNS uses to reach the DNS server (host LAN IP)
  dns_reachable_address = "192.168.68.84:5353"

  # Allow CoreDNS to request zone transfers
  # Use the OVN production network's NAT IP (volatile.network.ipv4.address)
  transfer_peers = {
    coredns = "192.168.68.3"  # OVN NAT IP for production network
  }
}
```

### With Custom Records

```hcl
module "network_zone" {
  source = "../../modules/incus-network-zone"

  zone_name             = "incus.accuser.dev"
  dns_listen_address    = ":5353"
  dns_reachable_address = "192.168.68.84:5353"

  transfer_peers = {
    coredns = "192.168.68.3"
  }

  custom_records = [
    {
      name        = "api"
      description = "API alias"
      entries = [
        {
          type  = "CNAME"
          value = "grafana01.incus.accuser.dev."
        }
      ]
    }
  ]
}
```

### Multi-Environment (with Incus Peers)

```hcl
module "network_zone" {
  source = "../../modules/incus-network-zone"

  zone_name             = "incus.accuser.dev"
  dns_listen_address    = ":5353"
  dns_reachable_address = "192.168.68.84:5353"

  # Include containers from cluster01 Incus remote
  peers = {
    cluster01 = {
      address = "192.168.1.100:8443"
    }
  }

  transfer_peers = {
    coredns = "192.168.68.3"
  }
}
```

## Network Linking

Networks must be linked to the zone to generate records. This is done via the `dns.zone.forward` configuration on the network:

```hcl
resource "incus_network" "management" {
  name = "management"
  type = "bridge"

  config = {
    "ipv4.address"     = "10.20.0.1/24"
    "dns.zone.forward" = module.network_zone.zone_name
  }
}
```

## CoreDNS Integration

The zone supports AXFR zone transfers. Configure CoreDNS as a secondary:

```
incus.accuser.dev:53 {
    secondary {
        transfer from 192.168.68.84:5353
    }
    log
    errors
    cache 60
}
```

## Important: Zone Transfer Authentication

Incus uses **IP-based authentication** for zone transfers. The source IP of the zone transfer request must match a configured peer address.

For OVN networks, containers connect to the host via NAT. The source IP the host sees is the **OVN network's NAT IP** (found in `volatile.network.ipv4.address`), not the container's internal IP.

To find the NAT IP:
```bash
incus network show ovn-production | grep volatile.network.ipv4.address
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| incus | >= 1.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| zone_name | DNS zone name | `string` | n/a | yes |
| description | Zone description | `string` | `"Incus container DNS zone"` | no |
| default_ttl | Default TTL for records | `number` | `300` | no |
| peers | Peer Incus servers for multi-environment | `map(object)` | `{}` | no |
| transfer_peers | DNS servers allowed to request zone transfers (IP addresses) | `map(string)` | `{}` | no |
| configure_dns_server | Configure Incus DNS server | `bool` | `true` | no |
| dns_listen_address | DNS server listen address | `string` | `":5353"` | no |
| dns_reachable_address | Address CoreDNS uses to reach DNS server | `string` | `""` | no |
| custom_records | Custom zone records | `list(object)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| zone_name | Name of the created zone |
| dns_server_address | Incus DNS server listen address |
| dns_reachable_address | Address CoreDNS can reach the DNS server |
| zone_transfer_enabled | Whether zone transfer is enabled |
| secondary_zone_config | Configuration for CoreDNS secondary zone |
