# Loki Terraform Module

This module deploys Grafana Loki on Incus for log aggregation and querying.

## Features

- **Log Aggregation**: Collects and indexes logs from all services
- **LogQL**: Powerful query language for log exploration
- **Retention Management**: Configurable log retention policies
- **Persistent Storage**: Optional persistent volume for log data
- **Optional TLS**: Certificate management via step-ca
- **Profile Composition**: Works with base-infrastructure module profiles

## Usage

```hcl
module "loki01" {
  source = "./modules/loki"

  instance_name = "loki01"
  profile_name  = "loki"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  enable_data_persistence = true
  data_volume_name        = "loki01-data"
  data_volume_size        = "50GB"

  # Retention settings
  retention_period       = "720h"  # 30 days
  retention_delete_delay = "2h"
}
```

## Retention Configuration

Loki supports time-based retention to automatically delete old logs:

| Duration | Hours | Use Case |
|----------|-------|----------|
| 7 days | `168h` | Development/testing |
| 14 days | `336h` | Short-term retention |
| 30 days | `720h` | Standard retention (default) |
| 90 days | `2160h` | Extended retention |

```hcl
module "loki01" {
  # ...
  retention_period       = "720h"  # Keep logs for 30 days
  retention_delete_delay = "2h"    # Wait 2h before deleting
}
```

## Grafana Integration

Configure Loki as a datasource in Grafana:

```hcl
module "grafana01" {
  # ...
  datasources = [
    {
      name       = "Loki"
      type       = "loki"
      url        = module.loki01.loki_endpoint
      is_default = false
    }
  ]
}
```

## Incus Native Logging

Loki can receive logs directly from Incus using the incus-loki module:

```hcl
module "incus_loki" {
  source = "./modules/incus-loki"

  logging_name   = "loki01"
  loki_address   = module.loki01.loki_endpoint_ip
  instance_types = "container,virtual-machine"
  event_types    = "lifecycle,logging"
}
```

This enables:
- **Lifecycle events**: Instance start/stop, create, delete
- **Logging events**: Container and VM log output

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the Loki instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `profiles` | List of Incus profile names to apply | `list(string)` | `["default"]` | no |
| `image` | Container image to use | `string` | `"ghcr:accuser-dev/atlas/loki:latest"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"2"` | no |
| `memory_limit` | Memory limit (e.g., "2GB") | `string` | `"2GB"` | no |
| `storage_pool` | Storage pool for the data volume | `string` | `"local"` | no |
| `enable_data_persistence` | Enable persistent storage | `bool` | `false` | no |
| `data_volume_name` | Name of the storage volume | `string` | `"loki-data"` | no |
| `data_volume_size` | Size of storage volume (min 10GB) | `string` | `"50GB"` | no |
| `loki_port` | Port Loki listens on | `string` | `"3100"` | no |
| `retention_period` | Log retention period (e.g., "720h") | `string` | `"720h"` | no |
| `retention_delete_delay` | Delay before deletion (min 2h) | `string` | `"2h"` | no |
| `environment_variables` | Additional environment variables | `map(string)` | `{}` | no |
| `enable_tls` | Enable TLS via step-ca | `bool` | `false` | no |
| `stepca_url` | step-ca server URL | `string` | `""` | no |
| `stepca_fingerprint` | step-ca root certificate fingerprint | `string` | `""` | no |
| `cert_duration` | TLS certificate duration | `string` | `"24h"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `profile_name` | Name of the created profile |
| `instance_status` | Status of the instance |
| `storage_volume_name` | Name of the storage volume (if enabled) |
| `loki_endpoint` | Internal endpoint URL (using .incus DNS) |
| `loki_endpoint_ip` | Endpoint URL using IP address |
| `ipv4_address` | IPv4 address of the instance |
| `tls_enabled` | Whether TLS is enabled |

## Troubleshooting

### Check Loki status

```bash
incus exec loki01 -- wget -qO- http://localhost:3100/ready
```

### View Loki metrics

```bash
incus exec loki01 -- wget -qO- http://localhost:3100/metrics | head -50
```

### Query logs via API

```bash
# Query last 10 log entries
incus exec loki01 -- wget -qO- 'http://localhost:3100/loki/api/v1/query_range?query={job="varlogs"}&limit=10'
```

### Check storage usage

```bash
incus exec loki01 -- du -sh /loki
```

### View configuration

```bash
incus exec loki01 -- cat /etc/loki/local-config.yaml
```

## LogQL Examples

Query logs in Grafana using LogQL:

```logql
# All logs from a specific job
{job="grafana"}

# Filter by log level
{job="grafana"} |= "error"

# Regex matching
{job="grafana"} |~ "user.*login"

# JSON parsing
{job="api"} | json | status >= 400

# Rate of errors
rate({job="api"} |= "error" [5m])
```

## Related Modules

- [grafana](../grafana/) - Visualizes Loki logs
- [incus-loki](../incus-loki/) - Configures Incus to send logs to Loki
- [step-ca](../step-ca/) - Provides TLS certificates
- [base-infrastructure](../base-infrastructure/) - Provides base profiles

## References

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Loki Configuration](https://grafana.com/docs/loki/latest/configure/)
- [Retention Configuration](https://grafana.com/docs/loki/latest/operations/storage/retention/)
