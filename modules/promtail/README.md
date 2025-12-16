# Promtail Module

This module deploys Promtail as a log shipping agent that forwards logs to a central Loki instance.

## Overview

Promtail is deployed as an Alpine Linux system container with cloud-init configuration. It scrapes local logs and ships them to a remote Loki instance.

## Usage

```hcl
module "promtail01" {
  source = "../../modules/promtail"

  instance_name = "promtail01"
  profile_name  = "promtail"

  loki_push_url = "http://loki01.iapetus:3100/loki/api/v1/push"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  extra_labels = {
    environment = "cluster"
    datacenter  = "home"
  }
}
```

## Cross-Environment Log Shipping

This module is designed for shipping logs from one Incus environment to another:

```
cluster (production workloads)     iapetus (control plane)
┌─────────────────────────┐        ┌─────────────────────────┐
│  promtail01             │───────>│  loki01                 │
│  (scrapes local logs)   │  HTTP  │  (aggregates all logs)  │
└─────────────────────────┘        └─────────────────────────┘
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `instance_name` | Name of the Promtail instance | `string` | - |
| `profile_name` | Name of the Incus profile | `string` | - |
| `loki_push_url` | URL of Loki push endpoint | `string` | - |
| `promtail_version` | Version of Promtail to install | `string` | `3.3.2` |
| `cpu_limit` | CPU limit for container | `string` | `1` |
| `memory_limit` | Memory limit for container | `string` | `256MB` |
| `extra_labels` | Additional labels for log entries | `map(string)` | `{}` |
| `target_node` | Cluster node to pin instance to | `string` | `""` |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `promtail_endpoint` | HTTP API endpoint URL |
| `ipv4_address` | IPv4 address of the instance |
| `loki_push_url` | Configured Loki push URL |

## Log Sources

By default, Promtail scrapes:

1. **Journal logs** - System journal entries (syslog_identifier, unit, level)
2. **System logs** - Files matching `/var/log/*.log`

## Labels

All log entries include:
- `host` - The Promtail instance name
- `job` - Either `journal` or `system`
- Any labels from `extra_labels` variable

## Resource Requirements

| Resource | Default | Minimum |
|----------|---------|---------|
| CPU | 1 core | 1 core |
| Memory | 256MB | 128MB |
| Disk | 512MB | 256MB |

## Network Requirements

Promtail requires outbound HTTP/HTTPS access to the Loki instance. Ensure the management network can route to the Loki endpoint.
