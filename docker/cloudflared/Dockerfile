# Cloudflare Tunnel client for secure remote access
# Uses the official cloudflared image
FROM cloudflare/cloudflared:latest

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Cloudflare Tunnel client for secure remote access via Zero Trust"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.title="Atlas Cloudflared"
LABEL org.opencontainers.image.description="Cloudflare Tunnel client for Zero Trust remote access"
LABEL org.opencontainers.image.vendor="accuser"

# Health check using cloudflared's built-in ready endpoint
# Note: Metrics server must be enabled (--metrics localhost:2000)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:2000/ready || exit 1

# Default entrypoint runs the tunnel
# Token is passed via TUNNEL_TOKEN environment variable
ENTRYPOINT ["cloudflared", "tunnel"]
CMD ["--metrics", "localhost:2000", "run"]
