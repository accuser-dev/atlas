# Atlas Mosquitto MQTT Broker

Custom Eclipse Mosquitto image with TLS support via step-ca for the Atlas infrastructure.

## Features

- Based on official `eclipse-mosquitto:2.0.21` image
- Optional TLS support via internal step-ca ACME
- Automatic certificate provisioning and renewal
- Configurable MQTT (1883) and MQTTS (8883) ports
- Password file authentication support
- Health check via MQTT subscription

## Build

```bash
# Build locally
docker build -t mosquitto:local .

# Or use the Makefile from project root
make build-mosquitto
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_TLS` | `false` | Enable TLS via step-ca |
| `STEPCA_URL` | (required if TLS) | step-ca ACME endpoint URL |
| `STEPCA_FINGERPRINT` | (required if TLS) | step-ca root CA fingerprint |
| `CERT_DURATION` | `24h` | Certificate validity duration |
| `MQTT_PORT` | `1883` | Plain MQTT listener port |
| `MQTTS_PORT` | `8883` | TLS MQTT listener port |

## Usage

### Basic (No TLS)

```bash
docker run -d \
  -p 1883:1883 \
  ghcr.io/accuser/atlas/mosquitto:latest
```

### With TLS

```bash
docker run -d \
  -p 1883:1883 \
  -p 8883:8883 \
  -e ENABLE_TLS=true \
  -e STEPCA_URL=https://step-ca01.incus:9000 \
  -e STEPCA_FINGERPRINT=abc123... \
  ghcr.io/accuser/atlas/mosquitto:latest
```

### With Authentication

Create a password file and mount it:

```bash
# Create password file
docker run --rm -v $(pwd)/passwd:/mosquitto/config/passwd \
  eclipse-mosquitto:2.0.21 \
  mosquitto_passwd -b /mosquitto/config/passwd myuser mypassword

# Run with authentication
docker run -d \
  -p 1883:1883 \
  -v $(pwd)/passwd:/mosquitto/config/passwd:ro \
  ghcr.io/accuser/atlas/mosquitto:latest
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 1883 | TCP | Plain MQTT |
| 8883 | TCP | MQTT over TLS |

## Volumes

| Path | Description |
|------|-------------|
| `/mosquitto/data` | Persistent message store and retained messages |
| `/mosquitto/config/passwd` | Optional password file for authentication |
| `/mosquitto/tls` | TLS certificates (auto-populated when TLS enabled) |

## Testing

```bash
# Subscribe to test topic
mosquitto_sub -h localhost -p 1883 -t 'test/#' -v

# Publish test message
mosquitto_pub -h localhost -p 1883 -t 'test/hello' -m 'Hello MQTT!'

# With TLS (using system CA or step-ca root)
mosquitto_sub -h localhost -p 8883 -t 'test/#' --cafile ca.crt

# Check broker status
mosquitto_sub -h localhost -p 1883 -t '$SYS/broker/#' -v -C 5
```

## Terraform Integration

This image is used by the `terraform/modules/mosquitto` module with Incus proxy devices for external access:

```hcl
module "mosquitto01" {
  source = "./modules/mosquitto"

  instance_name          = "mosquitto01"
  enable_external_access = true
  external_mqtt_port     = "1883"
  external_mqtts_port    = "8883"
  enable_tls             = true
}
```

## Security Considerations

- Anonymous access is disabled by default when a password file is provided
- TLS is recommended for any external access
- Use strong passwords and rotate them regularly
- Consider network-level access controls in addition to authentication
