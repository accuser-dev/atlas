# Alertmanager Docker Image

Custom Alertmanager image with optional TLS support via step-ca.

## Features

- Based on official `prom/alertmanager:v0.27.0`
- Optional TLS certificate provisioning via step-ca
- Health check endpoint
- Non-root user execution

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_TLS` | `false` | Enable TLS mode |
| `STEPCA_URL` | `` | step-ca server URL (required if TLS enabled) |
| `STEPCA_FINGERPRINT` | `` | step-ca root CA fingerprint (required if TLS enabled) |
| `CERT_DURATION` | `24h` | Certificate validity duration |

## Configuration

Alertmanager configuration should be mounted at `/etc/alertmanager/alertmanager.yml`.

### Example Configuration

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
    # Configure your notification channels here
    # slack_configs:
    #   - api_url: 'https://hooks.slack.com/services/...'
    #     channel: '#alerts'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname']
```

## Building

```bash
# Build locally (STEP_VERSION is required)
docker build --build-arg STEP_VERSION=$(cat ../../.step-version) -t alertmanager:latest .

# Build with specific step CLI version
docker build --build-arg STEP_VERSION=0.28.6 -t alertmanager:latest .
```

## Usage

```bash
# Run without TLS
docker run -d \
  -v /path/to/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  -p 9093:9093 \
  alertmanager:latest

# Run with TLS
docker run -d \
  -e ENABLE_TLS=true \
  -e STEPCA_URL=https://step-ca:9000 \
  -e STEPCA_FINGERPRINT=abc123... \
  -v /path/to/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  -p 9093:9093 \
  alertmanager:latest
```

## Ports

- `9093` - HTTP/HTTPS API and web UI

## Storage

- `/alertmanager` - Data directory for silences and notification state
