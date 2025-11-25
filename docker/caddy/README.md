# Caddy Custom Image

This directory contains the Dockerfile for building a custom Caddy image based on `caddybuilds/caddy-cloudflare`.

## Base Image

- **Base**: `caddybuilds/caddy-cloudflare:2.10.2`
- **Includes**: Caddy web server with Cloudflare DNS plugin for ACME DNS-01 challenges
- **Version**: Pinned to 2.10.2 for reproducibility and security (Dependabot tracks updates)

## Building

```bash
# From the docker/caddy directory
docker build -t atlas/caddy:latest .

# Or from the project root using the Makefile
make build-caddy
```

## Image Features

### Security Enhancements

**Container User**
- The `caddybuilds/caddy-cloudflare` base image runs as root
- Caddy internally manages privileges appropriately
- When deployed via Incus, the container runs with restricted capabilities
- Production deployments benefit from Incus container isolation

**Health Check**
- Built-in Docker/Incus health check
- Interval: 30 seconds
- Timeout: 3 seconds
- Retries: 3 attempts before marking unhealthy
- Command: `caddy version`
- Enables automatic restart policies and monitoring integration

### Operations

**Working Directory**
- Set to `/srv` for consistency
- Provides a predictable location for runtime operations

**OCI Labels**
- Standard Open Container Initiative metadata labels
- Enables better container registry integration
- Includes source repository, version, and description
- Facilitates automated tooling and documentation

## Customization

To add custom Caddy plugins or configuration:

1. Add plugin build instructions to the Dockerfile
2. Copy any static configuration files needed
3. Rebuild the image

### Example: Adding a Custom Plugin

```dockerfile
# After the FROM line, add:
RUN xcaddy build \
    --with github.com/example/caddy-plugin
```

## Usage in Terraform

The Terraform configuration expects this image to be available either:
- Published to GitHub Container Registry (ghcr.io) - default for production
- In a local registry accessible to Incus
- As an Incus image imported via `incus image import`

See the main project README for integration details.

## Production Deployment

Images are automatically built and published to `ghcr.io/accuser/atlas/caddy:latest` by GitHub Actions when code is pushed to `main` or `develop` branches.

For local development:
```bash
# Build locally
make build-caddy

# Test with OpenTofu
cd terraform
tofu plan
```
