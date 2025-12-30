# Alloy Terraform Module

This module deploys Grafana Alloy for log collection and shipping to a central Loki instance.

## Features

- **Log Collection**: Scrapes system logs and journals
- **Loki Integration**: Ships logs to central Loki via HTTP
- **Syslog Receiver**: Optional syslog input for remote hosts (e.g., IncusOS)
- **Cluster Support**: Pin to specific cluster nodes via `target_node`
- **Custom Labels**: Add extra labels to all log entries

## Usage

```hcl
module "alloy01" {
  source = "../../modules/alloy"

  instance_name = "alloy01"
  profile_name  = "alloy"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  loki_push_url = "http://loki01.incus:3100/loki/api/v1/push"

  extra_labels = {
    environment = "production"
    cluster     = "cluster01"
  }

  # Optional: Enable syslog receiver for IncusOS hosts
  enable_syslog_receiver = true
  syslog_port            = "1514"
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Alloy Container                          │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                  Grafana Alloy                        │  │
│   │                                                       │  │
│   │   /etc/alloy/config.alloy  (pipeline config)         │  │
│   │                                                       │  │
│   │   :12345/       ───► HTTP API / UI                   │  │
│   │   :1514/udp     ───► Syslog receiver (optional)      │  │
│   └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Log Sources                              │  │
│   │   • /var/log/messages (system logs)                  │  │
│   │   • Remote syslog (from IncusOS hosts)               │  │
│   └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│                    Loki (loki01.incus:3100)                 │
└─────────────────────────────────────────────────────────────┘
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the Alloy instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `loki_push_url` | Loki push API URL | `string` | n/a | yes |
| `profiles` | List of Incus profiles to apply | `list(string)` | `["default"]` | no |
| `image` | Container image | `string` | `"images:alpine/3.21/cloud"` | no |
| `alloy_version` | Grafana Alloy version | `string` | `"1.5.1"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit | `string` | `"256MB"` | no |
| `storage_pool` | Storage pool | `string` | `"local"` | no |
| `root_disk_size` | Root disk size | `string` | `"512MB"` | no |
| `http_port` | HTTP API/UI port | `string` | `"12345"` | no |
| `extra_labels` | Additional labels for logs | `map(string)` | `{}` | no |
| `target_node` | Target cluster node | `string` | `""` | no |
| `enable_syslog_receiver` | Enable syslog input | `bool` | `false` | no |
| `syslog_port` | Syslog UDP port | `string` | `"1514"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `http_endpoint` | HTTP API/UI endpoint |
| `syslog_endpoint` | Syslog receiver endpoint (if enabled) |

## Troubleshooting

### Check Alloy status

```bash
incus exec alloy01 -- rc-service alloy status
```

### View logs

```bash
incus exec alloy01 -- cat /var/log/alloy/alloy.log
```

### Check configuration

```bash
incus exec alloy01 -- cat /etc/alloy/config.alloy
```

### Test Loki connectivity

```bash
incus exec alloy01 -- wget -qO- http://loki01.incus:3100/ready
```

## Related Modules

- [loki](../loki/) - Central log aggregation (Alloy ships logs here)
- [grafana](../grafana/) - Visualize logs from Loki
- [base-infrastructure](../base-infrastructure/) - Provides base profiles

## References

- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Alloy Configuration Reference](https://grafana.com/docs/alloy/latest/reference/config-blocks/)
