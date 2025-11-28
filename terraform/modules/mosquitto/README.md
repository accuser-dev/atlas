# Mosquitto Terraform Module

This module deploys Eclipse Mosquitto MQTT broker on Incus for IoT messaging and pub/sub communication.

## Features

- **MQTT Protocol**: Lightweight publish/subscribe messaging
- **External Access**: Host port forwarding via Incus proxy devices
- **Authentication**: Password-based user authentication
- **Persistent Storage**: Optional persistent volume for retained messages
- **Optional TLS**: Certificate management via step-ca
- **Profile Composition**: Works with base-infrastructure module profiles

## Usage

```hcl
module "mosquitto01" {
  source = "./modules/mosquitto"

  instance_name = "mosquitto01"
  profile_name  = "mosquitto"

  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.production_network_profile.name,
  ]

  enable_data_persistence = true
  data_volume_name        = "mosquitto01-data"
  data_volume_size        = "5GB"

  enable_external_access = true
  external_mqtt_port     = "1883"

  # Optional: User authentication
  mqtt_users = {
    "sensor1" = "secret123"
    "app1"    = "anothersecret"
  }
}
```

## External Access

Mosquitto uses **Incus proxy devices** instead of Caddy reverse proxy for external access. This is because MQTT is a TCP protocol, not HTTP.

```
┌─────────────────────────────────────────────────────────────┐
│                      Host                                    │
│                                                              │
│   Port 1883 ──────────────────┐                             │
│   (external)                   │                             │
│                                ▼                             │
│   ┌─────────────────────────────────────────────┐           │
│   │              Mosquitto Container             │           │
│   │                                              │           │
│   │   mqtt-proxy: tcp:0.0.0.0:1883              │           │
│   │        └───► tcp:127.0.0.1:1883             │           │
│   │                                              │           │
│   │   (mqtts-proxy when TLS enabled)            │           │
│   └─────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

## Authentication

### Password-Based Authentication

Configure users via the `mqtt_users` variable:

```hcl
module "mosquitto01" {
  # ...
  mqtt_users = {
    "device1"  = var.mqtt_device1_password
    "backend"  = var.mqtt_backend_password
  }
}
```

**Security Note**: Store passwords in `terraform.tfvars` (gitignored) or environment variables:

```hcl
# terraform.tfvars
mqtt_device1_password = "secure-password-here"
```

### Anonymous Access

If `mqtt_users` is empty, anonymous access is allowed (not recommended for production).

## TLS Configuration

Enable encrypted MQTT (MQTTS) using step-ca certificates:

```hcl
module "mosquitto01" {
  # ...
  enable_tls         = true
  stepca_url         = module.step_ca01.acme_endpoint
  stepca_fingerprint = var.stepca_fingerprint

  enable_external_access = true
  external_mqtt_port     = "1883"   # Plain MQTT
  external_mqtts_port    = "8883"   # MQTT over TLS
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the Mosquitto instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `profiles` | List of Incus profile names to apply | `list(string)` | `["default"]` | no |
| `image` | Container image to use | `string` | `"ghcr:accuser/atlas/mosquitto:latest"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit (e.g., "256MB") | `string` | `"256MB"` | no |
| `storage_pool` | Storage pool for the data volume | `string` | `"local"` | no |
| `enable_data_persistence` | Enable persistent storage | `bool` | `false` | no |
| `data_volume_name` | Name of the storage volume | `string` | `"mosquitto-data"` | no |
| `data_volume_size` | Size of storage volume (min 100MB) | `string` | `"5GB"` | no |
| `mqtt_port` | Internal MQTT port | `string` | `"1883"` | no |
| `mqtts_port` | Internal MQTTS port | `string` | `"8883"` | no |
| `enable_external_access` | Enable external access via proxy | `bool` | `true` | no |
| `external_mqtt_port` | Host port for external MQTT | `string` | `"1883"` | no |
| `external_mqtts_port` | Host port for external MQTTS | `string` | `"8883"` | no |
| `mqtt_users` | Map of username to password | `map(string)` | `{}` | no |
| `mosquitto_config` | Custom configuration to append | `string` | `""` | no |
| `environment_variables` | Additional environment variables | `map(string)` | `{}` | no |
| `enable_tls` | Enable TLS via step-ca | `bool` | `false` | no |
| `stepca_url` | step-ca server URL | `string` | `""` | no |
| `stepca_fingerprint` | step-ca root certificate fingerprint | `string` | `""` | no |
| `cert_duration` | TLS certificate duration | `string` | `"24h"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `mqtt_endpoint` | Internal MQTT endpoint URL |
| `mqtts_endpoint` | Internal MQTTS endpoint (if TLS enabled) |
| `external_mqtt_port` | Host port for external MQTT |
| `external_mqtts_port` | Host port for external MQTTS |
| `tls_enabled` | Whether TLS is enabled |
| `external_access_enabled` | Whether external access is enabled |

## Troubleshooting

### Test MQTT connection

```bash
# From the host (requires mosquitto-clients)
mosquitto_pub -h localhost -p 1883 -t "test/topic" -m "Hello"
mosquitto_sub -h localhost -p 1883 -t "test/topic"

# With authentication
mosquitto_pub -h localhost -p 1883 -u "device1" -P "password" -t "test/topic" -m "Hello"
```

### Check Mosquitto status

```bash
incus exec mosquitto01 -- cat /mosquitto/log/mosquitto.log
```

### View active connections

```bash
incus exec mosquitto01 -- mosquitto_ctrl -h localhost -u admin list clients
```

### Verify configuration

```bash
incus exec mosquitto01 -- cat /mosquitto/config/mosquitto.conf
```

### Test from within container

```bash
incus exec mosquitto01 -- mosquitto_pub -h localhost -t "test" -m "hello"
```

## Custom Configuration

Add custom Mosquitto configuration:

```hcl
module "mosquitto01" {
  # ...
  mosquitto_config = <<-EOT
    # Custom settings
    max_connections 1000
    max_inflight_messages 20
    max_queued_messages 1000

    # Logging
    log_type all
    log_dest file /mosquitto/log/mosquitto.log
  EOT
}
```

## Related Modules

- [step-ca](../step-ca/) - Provides TLS certificates
- [base-infrastructure](../base-infrastructure/) - Provides base profiles

## References

- [Eclipse Mosquitto](https://mosquitto.org/)
- [Mosquitto Configuration](https://mosquitto.org/man/mosquitto-conf-5.html)
- [MQTT Protocol](https://mqtt.org/)
