# Incus Loki Module

This module configures Incus to natively push logs to a Loki server, eliminating the need for external log shippers like Promtail.

## Overview

Incus has built-in support for sending logs directly to Loki. This module configures the Incus server with the appropriate logging target settings. Once configured, Incus will push:

- **Lifecycle events** - Instance start/stop, creation, deletion, snapshots, etc.
- **Logging events** - Container and VM log output
- **Network ACL events** - Network access control list activity

## Usage

```hcl
module "incus_loki" {
  source = "./modules/incus-loki"

  logging_name = "loki01"
  loki_address = "http://loki01.incus:3100"
  log_types    = "lifecycle,logging"
}
```

## Requirements

| Name | Version |
|------|---------|
| incus | >= 1.0.0 |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `logging_name` | Unique name for the logging target | `string` | `"loki01"` |
| `loki_address` | Loki server address with protocol and port | `string` | **required** |
| `log_types` | Event types to send (lifecycle, logging, network-acl) | `string` | `"lifecycle,logging"` |
| `labels` | Labels to include in Loki log entries | `string` | `""` |
| `instance_name` | Instance field value in Loki events | `string` | `""` (hostname) |
| `retry_count` | Number of delivery retry attempts | `number` | `3` |
| `username` | Username for Loki authentication | `string` | `""` |
| `password` | Password for Loki authentication | `string` | `""` |
| `ca_cert` | CA certificate for HTTPS connections | `string` | `""` |
| `lifecycle_types` | Instance types for lifecycle events | `string` | `""` (all) |
| `lifecycle_projects` | Projects for lifecycle events | `string` | `""` (all) |

## Outputs

| Name | Description |
|------|-------------|
| `logging_name` | Name of the logging configuration |
| `loki_address` | Loki server address being used |
| `log_types` | Event types being sent to Loki |
| `config_keys` | List of Incus server config keys that were set |

## Log Types

| Type | Description |
|------|-------------|
| `lifecycle` | Instance lifecycle events (start, stop, create, delete, etc.) |
| `logging` | Container and VM log output |
| `network-acl` | Network ACL rule matches and actions |

## Querying Logs in Grafana

Once configured, logs will appear in Grafana's Explore view with the Loki datasource:

```logql
{job="incus"}
```

Filter by event type:
```logql
{job="incus", type="lifecycle"}
```

Filter by instance:
```logql
{job="incus", instance=~".*grafana.*"}
```

## Verification

Check if logging is configured:
```bash
incus config show | grep logging
```

View logs in Loki:
```bash
incus exec loki01 -- wget -q -O - 'http://localhost:3100/loki/api/v1/labels'
```

## Notes

- Incus pushes logs directly to Loki's HTTP API (`/loki/api/v1/push`)
- No external log shipper (Promtail, Alloy) is required
- Logs are pushed in real-time as events occur
- The configuration is applied at the Incus server level (global scope)
- Multiple logging targets can be configured with different names

## Important: Address Resolution

**The Incus daemon runs on the host**, not inside containers. This means:
- It **cannot** resolve `.incus` DNS names (e.g., `loki01.incus`)
- You must use the **IP address** of the Loki container
- Use `module.loki01.loki_endpoint_ip` instead of `module.loki01.loki_endpoint`

If you see no logs in Loki, check the address configuration:
```bash
incus config show | grep logging
```
