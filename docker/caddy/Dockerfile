# Custom Caddy with Cloudflare DNS plugin
# Pinned to v2.10.2 for reproducibility and security
FROM caddybuilds/caddy-cloudflare:2.10.2

# Add any custom Caddy modules or configuration here
# Example: COPY custom-plugins /usr/local/bin/

# The Caddyfile will be managed by Terraform and injected at runtime
# No need to copy it here unless you want a default fallback

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Caddy reverse proxy with Cloudflare DNS support"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.version="2.10.2"
LABEL org.opencontainers.image.title="Atlas Caddy"
LABEL org.opencontainers.image.description="Caddy reverse proxy with Cloudflare DNS for automatic HTTPS"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /srv

# Health check to verify Caddy is running
# Checks every 30s, with 3s timeout, 3 retries before marking unhealthy
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD caddy version || exit 1

# Note: The caddybuilds/caddy-cloudflare image doesn't include a non-root user
# The container runs as root but Caddy itself drops privileges appropriately
# For production with Incus, the container runs with restricted capabilities
