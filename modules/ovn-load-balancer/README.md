# OVN Load Balancer Terraform Module

This module creates OVN network load balancers for exposing services on LAN-routable VIPs.

## Features

- **Layer 4 Load Balancing**: TCP and UDP support
- **LAN-Routable VIPs**: External access without proxy devices
- **Multiple Backends**: Distribute traffic across containers
- **Multiple Ports**: Single VIP with multiple port mappings
- **Health Checks**: Automatic backend health monitoring (OVN native)
- **OVN Native**: Uses Incus OVN load balancer resources

## Usage

```hcl
module "mosquitto_lb" {
  source = "../../modules/ovn-load-balancer"

  network_name   = module.base.production_network.name
  listen_address = "192.168.68.10"
  description    = "Mosquitto MQTT broker"

  backends = [
    {
      name           = "mosquitto01"
      target_address = "10.10.0.20"
    }
  ]

  ports = [
    { listen_port = 1883, description = "MQTT" },
    { listen_port = 8883, description = "MQTTS" },
  ]
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    LAN / Physical Network                    │
│                                                              │
│   Client ───► 192.168.68.10:1883 (VIP)                      │
│                              │                               │
└──────────────────────────────┼──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    OVN Load Balancer                         │
│                                                              │
│   VIP: 192.168.68.10                                        │
│   Ports: 1883/tcp, 8883/tcp                                 │
│                              │                               │
│                              ▼                               │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Backend Pool                             │  │
│   │   mosquitto01 (10.10.0.20:1883)                      │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Single Backend Service

```hcl
module "coredns_lb" {
  source = "../../modules/ovn-load-balancer"

  network_name   = "ovn-production"
  listen_address = "192.168.68.11"
  description    = "CoreDNS"

  backends = [
    {
      name           = "coredns01"
      target_address = "10.10.0.53"
    }
  ]

  ports = [
    { listen_port = 53, protocol = "tcp", description = "DNS TCP" },
    { listen_port = 53, protocol = "udp", description = "DNS UDP" },
  ]
}
```

### Multiple Backends (Load Balancing)

```hcl
module "web_lb" {
  source = "../../modules/ovn-load-balancer"

  network_name   = "ovn-production"
  listen_address = "192.168.68.20"
  description    = "Web servers"

  backends = [
    { name = "web01", target_address = "10.10.0.10" },
    { name = "web02", target_address = "10.10.0.11" },
    { name = "web03", target_address = "10.10.0.12" },
  ]

  ports = [
    { listen_port = 80, description = "HTTP" },
    { listen_port = 443, description = "HTTPS" },
  ]
}
```

### Custom Target Ports

When backend port differs from listen port:

```hcl
module "grafana_lb" {
  source = "../../modules/ovn-load-balancer"

  network_name   = "ovn-management"
  listen_address = "192.168.68.30"

  backends = [
    {
      name           = "grafana01"
      target_address = "10.20.0.10"
      target_port    = 3000  # Grafana's internal port
    }
  ]

  ports = [
    { listen_port = 80 },  # External port 80 → internal 3000
  ]
}
```

### Health Checks

Enable automatic health monitoring to remove unhealthy backends from rotation:

```hcl
module "web_lb" {
  source = "../../modules/ovn-load-balancer"

  network_name   = "ovn-production"
  listen_address = "192.168.68.20"

  backends = [
    { name = "web01", target_address = "10.10.0.10" },
    { name = "web02", target_address = "10.10.0.11" },
  ]

  ports = [
    { listen_port = 80 },
  ]

  # Enable health checks with custom settings
  health_check = {
    enabled       = true
    interval      = 5     # Check every 5 seconds
    timeout       = 10    # Timeout after 10 seconds
    failure_count = 3     # Mark offline after 3 failures
    success_count = 2     # Mark online after 2 successes
  }
}
```

Health checks are TCP-based and test connectivity to each backend's target port.

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `network_name` | OVN network name | `string` | n/a | yes |
| `listen_address` | VIP address (must be in uplink's ipv4.ovn.ranges) | `string` | n/a | yes |
| `backends` | Backend targets | `list(object)` | n/a | yes |
| `ports` | Port mappings | `list(object)` | n/a | yes |
| `description` | Load balancer description | `string` | `""` | no |
| `health_check` | Health check configuration | `object` | `{}` | no |

### Backend Object

| Field | Description | Type | Default |
|-------|-------------|------|---------|
| `name` | Backend identifier | `string` | required |
| `target_address` | Backend IP address | `string` | required |
| `target_port` | Override port (optional) | `number` | listen_port |
| `description` | Backend description | `string` | `""` |

### Port Object

| Field | Description | Type | Default |
|-------|-------------|------|---------|
| `listen_port` | Port to listen on | `number` | required |
| `protocol` | `tcp` or `udp` | `string` | `"tcp"` |
| `target_backends` | Subset of backends (optional) | `list(string)` | all |
| `description` | Port description | `string` | `""` |

### Health Check Object

| Field | Description | Type | Default |
|-------|-------------|------|---------|
| `enabled` | Enable health checks | `bool` | `false` |
| `interval` | Seconds between health checks | `number` | `10` |
| `timeout` | Seconds before check times out | `number` | `30` |
| `failure_count` | Failures before marking offline | `number` | `3` |
| `success_count` | Successes before marking online | `number` | `3` |

## Outputs

| Name | Description |
|------|-------------|
| `listen_address` | Configured VIP address |
| `network` | Network the load balancer is attached to |
| `backends` | Configured backends |
| `ports` | Configured port mappings |
| `health_check_enabled` | Whether health checks are enabled |

## Prerequisites

### OVN Uplink Configuration

The VIP must be within the uplink network's `ipv4.ovn.ranges`:

```bash
# Configure the uplink network (typically done once)
incus network set eno1 ipv4.ovn.ranges=192.168.68.10-192.168.68.50
```

### OVN Network

The target network must be an OVN network:

```hcl
# In base-infrastructure module
resource "incus_network" "production" {
  name = "ovn-production"
  type = "ovn"
  # ...
}
```

## Troubleshooting

### List load balancers

```bash
incus network load-balancer list ovn-production
```

### Show load balancer details

```bash
incus network load-balancer show ovn-production 192.168.68.10
```

### Test connectivity

```bash
# From LAN client
nc -zv 192.168.68.10 1883

# Check OVN logical flows
ovn-sbctl lflow-list | grep load_balancer
```

### Verify VIP in OVN

```bash
ovn-nbctl lb-list
```

## Related Modules

- [ovn-central](../ovn-central/) - OVN databases (required)
- [ovn-config](../ovn-config/) - Incus OVN configuration
- [base-infrastructure](../base-infrastructure/) - Creates OVN networks
- [mosquitto](../mosquitto/) - Service exposed via OVN LB
- [coredns](../coredns/) - Service exposed via OVN LB

## References

- [Incus Network Load Balancers](https://linuxcontainers.org/incus/docs/main/howto/network_load_balancers/)
- [OVN Load Balancing](https://docs.ovn.org/en/latest/tutorials/ovn-lb.html)
