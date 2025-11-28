# Alertmanager Terraform Module

This module deploys Prometheus Alertmanager on Incus for alert routing, grouping, and notification management.

## Features

- **Alert Routing**: Configurable routes for different alert types
- **Notification Channels**: Support for Slack, email, webhook, and more
- **Silencing**: Persistent storage for silence rules
- **Inhibition Rules**: Suppress alerts based on other active alerts
- **Optional TLS**: Certificate management via step-ca
- **Profile Composition**: Works with base-infrastructure module profiles

## Usage

```hcl
module "alertmanager01" {
  source = "./modules/alertmanager"

  instance_name = "alertmanager01"
  profile_name  = "alertmanager"

  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.management_network_profile.name,
  ]

  enable_data_persistence = true
  data_volume_name        = "alertmanager01-data"
  data_volume_size        = "1GB"

  # Optional: Custom configuration
  alertmanager_config = file("${path.module}/alertmanager.yml")
}
```

## Configuration

### Default Configuration

If no custom configuration is provided, Alertmanager uses a minimal default:

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'

receivers:
  - name: 'default'
    # No notification channels configured

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname']
```

### Custom Configuration Example

```yaml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/xxx'

route:
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'slack-notifications'
  routes:
    - match:
        severity: critical
      receiver: 'slack-critical'

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#alerts'
        send_resolved: true

  - name: 'slack-critical'
    slack_configs:
      - channel: '#alerts-critical'
        send_resolved: true
```

## Prometheus Integration

Configure Prometheus to send alerts to Alertmanager:

```yaml
# In prometheus.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager01.incus:9093']
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the Alertmanager instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `profiles` | List of Incus profile names to apply | `list(string)` | `["default"]` | no |
| `image` | Container image to use | `string` | `"ghcr:accuser/atlas/alertmanager:latest"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit (e.g., "256MB") | `string` | `"256MB"` | no |
| `storage_pool` | Storage pool for the data volume | `string` | `"local"` | no |
| `enable_data_persistence` | Enable persistent storage | `bool` | `false` | no |
| `data_volume_name` | Name of the storage volume | `string` | `"alertmanager-data"` | no |
| `data_volume_size` | Size of storage volume (min 100MB) | `string` | `"1GB"` | no |
| `alertmanager_port` | Port Alertmanager listens on | `string` | `"9093"` | no |
| `alertmanager_config` | Custom alertmanager.yml content | `string` | `""` | no |
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
| `alertmanager_endpoint` | Internal endpoint URL |
| `tls_enabled` | Whether TLS is enabled |

## Troubleshooting

### Check Alertmanager status

```bash
incus exec alertmanager01 -- wget -qO- http://localhost:9093/-/healthy
```

### View active alerts

```bash
incus exec alertmanager01 -- wget -qO- http://localhost:9093/api/v2/alerts | jq
```

### Check configuration

```bash
incus exec alertmanager01 -- cat /etc/alertmanager/alertmanager.yml
```

### View logs

```bash
incus exec alertmanager01 -- cat /var/log/alertmanager.log
```

## Related Modules

- [prometheus](../prometheus/) - Sends alerts to Alertmanager
- [step-ca](../step-ca/) - Provides TLS certificates
- [base-infrastructure](../base-infrastructure/) - Provides base profiles

## References

- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Notification Integrations](https://prometheus.io/docs/alerting/latest/notification_examples/)
