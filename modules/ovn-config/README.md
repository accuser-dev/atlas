# OVN Config Terraform Module

This module configures Incus server-level OVN settings for connecting to OVN Central databases.

## Features

- **Server Configuration**: Sets `network.ovn.northbound_connection`
- **SSL Support**: Optional TLS certificates for secure connections
- **Integration Bridge**: Configure custom OVS integration bridge

## Usage

```hcl
module "ovn_config" {
  source = "../../modules/ovn-config"

  northbound_connection = "tcp:192.168.71.5:6641"
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Incus Server                              │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              OVN Configuration                        │  │
│   │                                                       │  │
│   │   network.ovn.northbound_connection                  │  │
│   │     = tcp:192.168.71.5:6641                          │  │
│   │                                                       │  │
│   │   (Optional SSL certificates)                        │  │
│   └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              OVN Central                              │  │
│   │   Northbound DB ◄─── Incus creates logical networks  │  │
│   │   Southbound DB ◄─── Chassis register here           │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Basic TCP Connection

```hcl
module "ovn_config" {
  source = "../../modules/ovn-config"

  northbound_connection = "tcp:192.168.71.5:6641"
}
```

### Multiple OVN Central Nodes (HA)

```hcl
module "ovn_config" {
  source = "../../modules/ovn-config"

  northbound_connection = "tcp:192.168.71.5:6641,tcp:192.168.71.2:6641,tcp:192.168.71.8:6641"
}
```

### SSL Connection

```hcl
module "ovn_config" {
  source = "../../modules/ovn-config"

  northbound_connection = "ssl:192.168.71.5:6641"
  ca_cert               = file("ovn-ca.crt")
  client_cert           = file("ovn-client.crt")
  client_key            = file("ovn-client.key")
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `northbound_connection` | OVN northbound connection string | `string` | n/a | yes |
| `ca_cert` | CA certificate (PEM) for SSL | `string` | `""` | no |
| `client_cert` | Client certificate (PEM) for SSL | `string` | `""` | no |
| `client_key` | Client private key (PEM) for SSL | `string` | `""` | no |
| `integration_bridge` | OVS integration bridge name | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| `northbound_connection` | Configured northbound connection |

## Known Issues

### HAProxy ETag Mismatch

When accessing Incus clusters via HAProxy load balancer, this resource may fail with ETag mismatch errors due to requests hitting different cluster nodes.

**Workaround**: Use `skip_ovn_config = true` in your environment and configure OVN via CLI instead:

```bash
incus config set network.ovn.northbound_connection=tcp:192.168.71.5:6641
```

## Troubleshooting

### Verify configuration

```bash
incus config get network.ovn.northbound_connection
```

### Test OVN connectivity

```bash
# From Incus server
ovn-nbctl --db=tcp:192.168.71.5:6641 show
```

### Create OVN network

```bash
# After configuration, create an OVN network
incus network create ovn-test --type=ovn
incus network show ovn-test
```

## Related Modules

- [ovn-central](../ovn-central/) - Deploys OVN databases
- [ovn-load-balancer](../ovn-load-balancer/) - OVN load balancers
- [base-infrastructure](../base-infrastructure/) - Creates OVN networks

## References

- [Incus OVN Configuration](https://linuxcontainers.org/incus/docs/main/howto/network_ovn_setup/)
- [OVN Northbound Database](https://docs.ovn.org/en/latest/ref/ovn-nb.5.html)
