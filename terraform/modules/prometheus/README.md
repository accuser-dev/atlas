# Prometheus Terraform Module

This module deploys Prometheus metrics collection and time-series database on Incus for infrastructure monitoring.

## Features

- **Time-Series Database**: Efficient storage for metrics data
- **Flexible Scraping**: Configurable scrape targets via prometheus.yml
- **Alert Rules**: Support for custom alerting rules
- **Incus Metrics**: mTLS authentication for scraping Incus container metrics
- **Retention Policies**: Time-based and size-based retention
- **Optional TLS**: Certificate management via step-ca
- **Profile Composition**: Works with base-infrastructure module profiles

## Usage

```hcl
module "prometheus01" {
  source = "./modules/prometheus"

  instance_name = "prometheus01"
  profile_name  = "prometheus"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  enable_data_persistence = true
  data_volume_name        = "prometheus01-data"
  data_volume_size        = "100GB"

  retention_time = "30d"
  retention_size = "90GB"

  prometheus_config = file("prometheus.yml")
  alert_rules       = file("alerts.yml")
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Prometheus Container                      │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                  Prometheus Server                    │  │
│   │                                                       │  │
│   │   /etc/prometheus/prometheus.yml  (scrape config)    │  │
│   │   /etc/prometheus/alerts/         (alert rules)      │  │
│   │   /prometheus                     (data storage)     │  │
│   │                                                       │  │
│   │   :9090/graph    ───► Query UI                       │  │
│   │   :9090/api      ───► HTTP API                       │  │
│   │   :9090/metrics  ───► Self-monitoring                │  │
│   └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Scrape Targets                           │  │
│   │   • grafana01.incus:3000/metrics                     │  │
│   │   • loki01.incus:3100/metrics                        │  │
│   │   • node-exporter01.incus:9100/metrics               │  │
│   │   • <incus-api>:8443/1.0/metrics (mTLS)              │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Prometheus Configuration File

Inject a custom `prometheus.yml` configuration:

```hcl
module "prometheus01" {
  # ...
  prometheus_config = <<-EOT
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'grafana'
        static_configs:
          - targets: ['grafana01.incus:3000']
            labels:
              service: 'grafana'

      - job_name: 'node'
        static_configs:
          - targets: ['node-exporter01.incus:9100']
            labels:
              service: 'node-exporter'
  EOT
}
```

### Alert Rules

Add custom alerting rules:

```hcl
module "prometheus01" {
  # ...
  alert_rules = <<-EOT
    groups:
      - name: service-availability
        rules:
          - alert: ServiceDown
            expr: up == 0
            for: 2m
            labels:
              severity: critical
            annotations:
              summary: "Service {{ $labels.job }} is down"
              description: "{{ $labels.instance }} has been unreachable for 2 minutes."

          - alert: HighMemoryUsage
            expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.9
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High memory usage detected"
              description: "Memory usage is above 90% for 5 minutes."
  EOT
}
```

### Incus Metrics (mTLS)

Scrape container metrics from the Incus API:

```hcl
module "incus_metrics" {
  source = "./modules/incus-metrics"
  # ... generates certificate and key
}

module "prometheus01" {
  # ...
  incus_metrics_certificate = module.incus_metrics.certificate_pem
  incus_metrics_private_key = module.incus_metrics.private_key_pem

  prometheus_config = <<-EOT
    scrape_configs:
      - job_name: 'incus'
        scheme: https
        tls_config:
          cert_file: /etc/prometheus/tls/metrics.crt
          key_file: /etc/prometheus/tls/metrics.key
          insecure_skip_verify: true
        static_configs:
          - targets: ['10.50.0.1:8443']
        metrics_path: /1.0/metrics
  EOT
}
```

## Retention Configuration

Prometheus supports both time-based and size-based retention:

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `retention_time` | How long to keep data | `30d` | `15d`, `90d`, `1y` |
| `retention_size` | Max storage size | `""` (disabled) | `50GB`, `90GB` |

When both are set, whichever limit is reached first triggers deletion:

```hcl
module "prometheus01" {
  # ...
  retention_time = "30d"    # Keep data for 30 days
  retention_size = "90GB"   # OR delete when storage exceeds 90GB
}
```

**Common retention configurations:**

| Use Case | Time | Size |
|----------|------|------|
| Development | `7d` | `10GB` |
| Production | `30d` | `90GB` |
| Long-term | `90d` | `500GB` |

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the Prometheus instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `profiles` | List of Incus profile names to apply | `list(string)` | `["default"]` | no |
| `image` | Container image to use | `string` | `"ghcr:accuser-dev/atlas/prometheus:latest"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"2"` | no |
| `memory_limit` | Memory limit (e.g., "2GB") | `string` | `"2GB"` | no |
| `storage_pool` | Storage pool for the data volume | `string` | `"local"` | no |
| `enable_data_persistence` | Enable persistent storage | `bool` | `false` | no |
| `data_volume_name` | Name of the storage volume | `string` | `"prometheus-data"` | no |
| `data_volume_size` | Size of storage volume (min 10GB) | `string` | `"100GB"` | no |
| `prometheus_port` | Port Prometheus listens on | `string` | `"9090"` | no |
| `prometheus_config` | Prometheus configuration (prometheus.yml) | `string` | `""` | no |
| `alert_rules` | Alert rules file content (alerts.yml) | `string` | `""` | no |
| `retention_time` | How long to retain metrics (e.g., "30d") | `string` | `"30d"` | no |
| `retention_size` | Max storage size before deletion | `string` | `""` | no |
| `environment_variables` | Additional environment variables | `map(string)` | `{}` | no |
| `enable_tls` | Enable TLS via step-ca | `bool` | `false` | no |
| `stepca_url` | step-ca server URL | `string` | `""` | no |
| `stepca_fingerprint` | step-ca root certificate fingerprint | `string` | `""` | no |
| `cert_duration` | TLS certificate duration | `string` | `"24h"` | no |
| `incus_metrics_certificate` | Certificate for Incus metrics scraping | `string` | `""` | no |
| `incus_metrics_private_key` | Private key for Incus metrics scraping | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `profile_name` | Name of the created profile |
| `instance_status` | Status of the instance |
| `storage_volume_name` | Name of the storage volume (if enabled) |
| `prometheus_endpoint` | Prometheus endpoint URL |
| `tls_enabled` | Whether TLS is enabled |

## Troubleshooting

### Check Prometheus status

```bash
incus exec prometheus01 -- wget -qO- http://localhost:9090/-/ready
```

### View scrape targets

```bash
# List all targets and their status
curl -s http://prometheus01.incus:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
```

### Check configuration

```bash
incus exec prometheus01 -- cat /etc/prometheus/prometheus.yml
```

### Query metrics

```bash
# Instant query
curl -s 'http://prometheus01.incus:9090/api/v1/query?query=up' | jq

# Range query (last hour)
curl -s 'http://prometheus01.incus:9090/api/v1/query_range?query=up&start='$(date -d '1 hour ago' +%s)'&end='$(date +%s)'&step=60' | jq
```

### Check storage usage

```bash
# Current storage size
curl -s http://prometheus01.incus:9090/api/v1/status/tsdb | jq '.data.headStats'
```

### View active alerts

```bash
curl -s http://prometheus01.incus:9090/api/v1/alerts | jq '.data.alerts'
```

### Reload configuration

```bash
# Send SIGHUP to Prometheus
incus exec prometheus01 -- pkill -HUP prometheus
```

## Grafana Integration

Add Prometheus as a data source in Grafana:

```hcl
module "grafana01" {
  # ...
  datasources = [
    {
      name       = "Prometheus"
      type       = "prometheus"
      url        = module.prometheus01.prometheus_endpoint
      is_default = true
    }
  ]
}
```

## Common PromQL Queries

```promql
# CPU usage across all containers
sum(rate(incus_cpu_seconds_total[5m])) by (name)

# Memory usage percentage
(incus_memory_MemTotal_bytes - incus_memory_MemAvailable_bytes) / incus_memory_MemTotal_bytes * 100

# Network traffic (bytes/sec)
rate(incus_network_receive_bytes_total[5m])
rate(incus_network_transmit_bytes_total[5m])

# Service uptime
up{job="grafana"}

# Request rate (if using a service with metrics)
rate(http_requests_total[5m])

# Alert firing count
ALERTS{alertstate="firing"}
```

## Related Modules

- [alertmanager](../alertmanager/) - Routes alerts from Prometheus
- [grafana](../grafana/) - Visualizes Prometheus metrics
- [loki](../loki/) - Log aggregation (complements metrics)
- [node-exporter](../node-exporter/) - Host-level metrics
- [incus-metrics](../incus-metrics/) - Incus container metrics
- [base-infrastructure](../base-infrastructure/) - Provides base profiles

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Storage](https://prometheus.io/docs/prometheus/latest/storage/)
