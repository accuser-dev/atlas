# Caddy Custom Image

This directory contains the Dockerfile for building a custom Caddy image with Cloudflare DNS and rate limiting plugins using xcaddy.

## Build Process

The image uses a multi-stage build:
1. **Builder stage**: Uses `caddy:2.10.2-builder-alpine` with xcaddy to compile Caddy with plugins
2. **Runtime stage**: Uses `caddy:2.10.2-alpine` for a minimal runtime environment

## Included Plugins

- **[caddy-dns/cloudflare](https://github.com/caddy-dns/cloudflare)**: Cloudflare DNS provider for ACME DNS-01 challenges
- **[mholt/caddy-ratelimit](https://github.com/mholt/caddy-ratelimit)**: Rate limiting with sliding window algorithm

## Building

```bash
# From the docker/caddy directory
docker build -t atlas/caddy:latest .

# Or from the project root using the Makefile
make build-caddy
```

## Image Features

### Cloudflare DNS Support

Enables automatic HTTPS certificate provisioning using Cloudflare DNS-01 challenges:
- Works with wildcard certificates
- No need to expose ports 80/443 during certificate issuance
- Supports Cloudflare API tokens for secure authentication

### Rate Limiting

Protects against brute force attacks, DoS attempts, and resource exhaustion:

**Default Configuration (per service):**
- General endpoints: 100 requests per minute per IP
- Login endpoints: 10 requests per minute per IP (stricter)

**Configurable via Terraform variables:**
```hcl
module "grafana01" {
  # ... other config

  # Rate limiting configuration
  enable_rate_limiting      = true   # Enable/disable rate limiting
  rate_limit_requests       = 100    # Requests per window
  rate_limit_window         = "1m"   # Time window (1m, 30s, 1h)
  login_rate_limit_requests = 10     # Stricter limit for login endpoints
  login_rate_limit_window   = "1m"   # Login endpoint time window
}
```

### Security Enhancements

**Container User**
- Base image runs Caddy with appropriate privileges
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

To add additional Caddy plugins:

1. Edit the Dockerfile's xcaddy build command
2. Add the plugin with `--with github.com/example/caddy-plugin`
3. Rebuild the image

### Example: Adding Another Plugin

```dockerfile
# In the builder stage, modify the xcaddy build:
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/mholt/caddy-ratelimit \
    --with github.com/example/another-plugin
```

## Usage in Terraform

The Terraform configuration expects this image to be available either:
- Published to GitHub Container Registry (ghcr.io) - default for production
- In a local registry accessible to Incus
- As an Incus image imported via `incus image import`

See the main project README for integration details.

## Production Deployment

Images are automatically built and published to `ghcr.io/accuser/atlas/caddy:latest` by GitHub Actions when code is pushed to the `main` branch.

For local development:
```bash
# Build locally
make build-caddy

# Test with OpenTofu
cd terraform
tofu plan
```

## Rate Limiting Details

The rate limiting plugin uses a sliding window algorithm with the following behavior:
- Requests are tracked per client IP address
- When the limit is exceeded, clients receive a `429 Too Many Requests` response
- The window slides continuously, providing smooth rate limiting
- Each service has its own rate limit zones to prevent cross-service interference

### Zone Naming

Rate limit zones are automatically named based on the domain:
- General zone: `grafana_accuser_dev` (domain with dots replaced by underscores)
- Login zone: `grafana_accuser_dev_login`

This ensures each service has isolated rate limiting.
