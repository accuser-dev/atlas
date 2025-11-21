# Custom Prometheus with pre-configured settings
# Pinned to v3.7.3 for reproducibility and security
FROM prom/prometheus:v3.7.3

# Add custom prometheus.yml if you want a default configuration
# Note: Terraform can also inject this configuration at runtime
# COPY prometheus.yml /etc/prometheus/prometheus.yml

# Add custom alert rules
# COPY alerts/ /etc/prometheus/alerts/

# Add custom recording rules
# COPY rules/ /etc/prometheus/rules/

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Prometheus with pre-configured rules and settings"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.version="3.7.3"
LABEL org.opencontainers.image.title="Atlas Prometheus"
LABEL org.opencontainers.image.description="Prometheus metrics collection for internal monitoring stack"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /prometheus

# Health check to verify Prometheus is running and responding
# Checks the ready endpoint which returns 200 when Prometheus is operational
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:9090/-/ready || exit 1

# Note: Official Prometheus image already runs as non-root user (nobody)
# No need to explicitly set USER directive
