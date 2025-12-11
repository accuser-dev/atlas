# Cloudflared Docker Image

Custom Docker image for Cloudflare Tunnel client, providing secure remote access to internal services via Cloudflare Zero Trust.

## Features

- Based on official `cloudflare/cloudflared:latest` image
- Token-based authentication (managed via Cloudflare dashboard)
- Built-in metrics endpoint for Prometheus scraping
- Health check for container monitoring

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `TUNNEL_TOKEN` | Cloudflare Tunnel token from Zero Trust dashboard | Yes |

### Metrics Endpoint

The container exposes a metrics endpoint at `localhost:2000` which provides:
- `/ready` - Health check endpoint
- `/metrics` - Prometheus metrics

## Usage

### Building Locally

```bash
# Build the image
make build-cloudflared

# Or with custom tag
IMAGE_TAG=dev make build-cloudflared
```

### Running with Docker

```bash
docker run -d \
  --name cloudflared \
  -e TUNNEL_TOKEN="your-tunnel-token" \
  ghcr.io/accuser-dev/atlas/cloudflared:latest
```

### Cloudflare Zero Trust Setup

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Networks** > **Tunnels**
3. Click **Create a tunnel**
4. Choose **Cloudflared** connector
5. Name your tunnel (e.g., `atlas-homelab`)
6. Copy the tunnel token
7. Configure public hostnames to route traffic to internal services

### Example Tunnel Configuration

In the Cloudflare dashboard, add public hostnames:

| Public Hostname | Service | URL |
|-----------------|---------|-----|
| `grafana.example.com` | HTTP | `http://grafana01.incus:3000` |
| `prometheus.example.com` | HTTP | `http://prometheus01.incus:9090` |

## Integration with Atlas

The cloudflared container connects to the management network and can reach all internal services:

- Grafana: `http://grafana01.incus:3000`
- Prometheus: `http://prometheus01.incus:9090`
- Loki: `http://loki01.incus:3100`
- Alertmanager: `http://alertmanager01.incus:9093`

## Security Considerations

- The tunnel token is sensitive and should be stored securely
- Use Cloudflare Access policies to control who can access exposed services
- Enable additional authentication (SSO, MFA) in Zero Trust settings
- Consider IP allowlisting for additional security layers
