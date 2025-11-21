# Custom Loki with pre-configured settings
# Pinned to v3.6.0 for reproducibility and security
FROM grafana/loki:3.6.0

# Add custom loki-config.yaml if you want a default configuration
# Note: Terraform can also inject this configuration at runtime
# COPY loki-config.yaml /etc/loki/loki-config.yaml

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Loki log aggregation system"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.version="3.6.0"
LABEL org.opencontainers.image.title="Atlas Loki"
LABEL org.opencontainers.image.description="Loki log aggregation for internal monitoring stack"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /loki

# Health check to verify Loki is running and responding
# Checks the ready endpoint which returns 200 when Loki is operational
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1

# Note: Official Loki image already runs as non-root user (UID 10001)
# No need to explicitly set USER directive
