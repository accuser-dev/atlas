# Node Exporter Terraform Module

This module deploys Prometheus Node Exporter on Incus for host-level metrics collection.

## Features

- **Debian Trixie**: Uses Debian Trixie system container with systemd
- **Host Metrics**: CPU, memory, disk, network, and filesystem metrics
- **Read-Only Mounts**: Secure access to host filesystem via read-only mounts
- **Lightweight**: Minimal resource footprint
- **Prometheus Compatible**: Standard `/metrics` endpoint
- **Profile Composition**: Works with base-infrastructure module profiles
- **Systemd Integration**: Proper service management

## Usage

```hcl
module "node_exporter01" {
  source = "./modules/node-exporter"

  instance_name = "node-exporter01"
  profile_name  = "node-exporter"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]
}
```

## Architecture

Node Exporter collects metrics from the host system via read-only filesystem mounts:

```
┌─────────────────────────────────────────────────────────────┐
│                      Host System                             │
│                                                              │
│   /           ──────────────────────────────────────┐       │
│   /proc       ──────────────────────────────┐       │       │
│   /sys        ────────────────────┐         │       │       │
│                                    │         │       │       │
│   ┌────────────────────────────────┴─────────┴───────┴──┐   │
│   │              Node Exporter Container                 │   │
│   │                                                      │   │
│   │   /host      (read-only mount of /)                 │   │
│   │   /host/proc (read-only mount of /proc)             │   │
│   │   /host/sys  (read-only mount of /sys)              │   │
│   │                                                      │   │
│   │   :9100/metrics ───► Prometheus                     │   │
│   └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Metrics Collected

Node Exporter provides hundreds of metrics. Key categories include:

| Category | Example Metrics |
|----------|-----------------|
| CPU | `node_cpu_seconds_total`, `node_load1` |
| Memory | `node_memory_MemTotal_bytes`, `node_memory_MemAvailable_bytes` |
| Disk | `node_disk_io_time_seconds_total`, `node_disk_read_bytes_total` |
| Filesystem | `node_filesystem_avail_bytes`, `node_filesystem_size_bytes` |
| Network | `node_network_receive_bytes_total`, `node_network_transmit_bytes_total` |
| System | `node_boot_time_seconds`, `node_time_seconds` |

## Prometheus Integration

Add Node Exporter to Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter01.incus:9100']
        labels:
          service: 'node-exporter'
          instance: 'node-exporter01'
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the Node Exporter instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `profiles` | List of Incus profile names to apply | `list(string)` | `["default"]` | no |
| `image` | Container image to use | `string` | `"images:debian/trixie/cloud"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit (e.g., "256MB") | `string` | `"256MB"` | no |
| `node_exporter_port` | Port Node Exporter listens on | `string` | `"9100"` | no |
| `environment_variables` | Additional environment variables | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `profile_name` | Name of the created profile |
| `node_exporter_endpoint` | Metrics endpoint URL |

## Security

Node Exporter uses **read-only mounts** for security:

```hcl
device {
  name = "host-root"
  type = "disk"
  properties = {
    source   = "/"
    path     = "/host"
    readonly = "true"  # Cannot modify host filesystem
  }
}
```

The container also runs unprivileged:

```hcl
config = {
  "security.privileged" = "false"
}
```

## Troubleshooting

### Test metrics endpoint

```bash
curl http://node-exporter01.incus:9100/metrics | head -50
```

### Check specific metrics

```bash
# CPU usage
curl -s http://node-exporter01.incus:9100/metrics | grep node_cpu_seconds_total

# Memory usage
curl -s http://node-exporter01.incus:9100/metrics | grep node_memory_MemAvailable_bytes

# Disk space
curl -s http://node-exporter01.incus:9100/metrics | grep node_filesystem_avail_bytes
```

### Verify mounts inside container

```bash
incus exec node-exporter01 -- ls -la /host
incus exec node-exporter01 -- cat /host/proc/meminfo | head -10
```

### Check container status

```bash
incus exec node-exporter01 -- systemctl status node_exporter
```

### View logs

```bash
incus exec node-exporter01 -- journalctl -u node_exporter --no-pager -n 50
```

## Grafana Dashboards

Popular Node Exporter dashboards for Grafana:

- **Node Exporter Full**: Dashboard ID 1860
- **Node Exporter for Prometheus**: Dashboard ID 11074
- **Host Stats**: Dashboard ID 6287

Import via Grafana UI: Dashboards → Import → Enter dashboard ID

## Common PromQL Queries

```promql
# CPU usage percentage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage percentage
(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100

# Network traffic (bytes/sec)
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])

# System uptime
node_time_seconds - node_boot_time_seconds
```

## Related Modules

- [prometheus](../prometheus/) - Scrapes Node Exporter metrics
- [grafana](../grafana/) - Visualizes metrics
- [base-infrastructure](../base-infrastructure/) - Provides base profiles

## References

- [Node Exporter Documentation](https://prometheus.io/docs/guides/node-exporter/)
- [Node Exporter GitHub](https://github.com/prometheus/node_exporter)
- [Available Collectors](https://github.com/prometheus/node_exporter#collectors)
