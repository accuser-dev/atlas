# Caddy Custom Image

This directory contains the Dockerfile for building a custom Caddy image based on `caddybuilds/caddy-cloudflare`.

## Base Image

- **Base**: `caddybuilds/caddy-cloudflare:latest`
- **Includes**: Caddy web server with Cloudflare DNS plugin for ACME DNS-01 challenges

## Building

```bash
# From the docker/caddy directory
docker build -t atlas/caddy:latest .

# Or from the project root using the Makefile
make build-caddy
```

## Customization

To add custom Caddy plugins or configuration:

1. Add plugin build instructions to the Dockerfile
2. Copy any static configuration files needed
3. Rebuild the image

## Usage in Terraform

The Terraform configuration expects this image to be available either:
- In a local registry accessible to Incus
- As an Incus image imported via `incus image import`

See the main project README for integration details.
