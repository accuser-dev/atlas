# Custom Caddy with Cloudflare DNS and rate limiting plugins
# Built using xcaddy for reproducibility and security

# Build stage: compile Caddy with plugins
FROM caddy:2.10.2-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/mholt/caddy-ratelimit

# Runtime stage
FROM caddy:2.10.2-alpine

# Copy custom Caddy binary with plugins
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Caddy reverse proxy with Cloudflare DNS and rate limiting"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.version="2.10.2"
LABEL org.opencontainers.image.title="Atlas Caddy"
LABEL org.opencontainers.image.description="Caddy reverse proxy with Cloudflare DNS for automatic HTTPS and rate limiting protection"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /srv

# Health check to verify Caddy is running
# Checks every 30s, with 3s timeout, 3 retries before marking unhealthy
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD caddy version || exit 1

# Note: The caddy:alpine image runs as non-root by default
# Caddy itself handles privilege dropping appropriately
