# Custom Loki with pre-configured settings
# Pinned to v3.6.1 for reproducibility and security
FROM grafana/loki:3.6.1

# Add custom loki-config.yaml if you want a default configuration
# Note: Terraform can also inject this configuration at runtime
# COPY loki-config.yaml /etc/loki/loki-config.yaml

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Loki log aggregation system"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.version="3.6.1"
LABEL org.opencontainers.image.title="Atlas Loki"
LABEL org.opencontainers.image.description="Loki log aggregation for internal monitoring stack"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /loki

# Note: The official Loki image is scratch-based with no shell or tools
# HEALTHCHECK cannot be used as wget/curl are not available
# For orchestration, use external health checks (e.g., Docker Compose, Kubernetes probes)
# Health endpoint: GET http://localhost:3100/ready (returns "ready" when operational)

# Note: Official Loki image already runs as non-root user (UID 10001)
# No need to explicitly set USER directive
