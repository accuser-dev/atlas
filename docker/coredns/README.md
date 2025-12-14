# CoreDNS Docker Image

Split-horizon DNS server for internal service resolution in the Atlas infrastructure.

## Features

- Authoritative DNS for internal zones (e.g., `accuser.dev`)
- Forwards `.incus` queries to Incus DNS resolver
- Upstream forwarding for external domains (Cloudflare, Google)
- Health check endpoint on port 8080
- Prometheus metrics endpoint

## Configuration

CoreDNS configuration is injected via Terraform file blocks:

- `/etc/coredns/Corefile` - Main CoreDNS configuration
- `/etc/coredns/zones/<domain>.zone` - Zone file for internal services

### Corefile Structure

The Corefile defines three zones:

1. **Internal zone** (e.g., `accuser.dev`) - Authoritative for internal services
2. **Incus zone** (`.incus`) - Forwards to Incus DNS resolver
3. **Default zone** (`.`) - Forwards to upstream DNS servers

## Building

```bash
# Build locally for testing
make build-coredns

# Or build with custom tag
docker build -t coredns:test docker/coredns/
```

## Testing

```bash
# Start container with test configuration
docker run -d --name coredns-test \
  -v $(pwd)/test-corefile:/etc/coredns/Corefile:ro \
  -p 5353:53/udp -p 5353:53/tcp \
  coredns:test

# Query internal service
dig @localhost -p 5353 grafana.accuser.dev

# Query Incus DNS (will fail without Incus)
dig @localhost -p 5353 grafana01.incus

# Query external domain (forwarded upstream)
dig @localhost -p 5353 google.com

# Check health
curl http://localhost:8080/health
```

## Resource Requirements

| Resource | Value |
|----------|-------|
| CPU | 1 core |
| Memory | 128MB |
| Storage | None (stateless) |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 53 | UDP/TCP | DNS queries |
| 8080 | TCP | Health check endpoint |
| 9153 | TCP | Prometheus metrics (optional) |

## Environment Variables

CoreDNS uses the Corefile for configuration. No environment variables are required.

## Image Source

Published to GitHub Container Registry:
```
ghcr.io/accuser-dev/atlas/coredns:latest
```
