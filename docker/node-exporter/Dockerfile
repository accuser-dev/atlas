# Node Exporter for host-level metrics collection
# Pinned to v1.10.2 for reproducibility
FROM prom/node-exporter:v1.10.2

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Node Exporter for host-level metrics collection"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.version="1.10.2"
LABEL org.opencontainers.image.title="Atlas Node Exporter"
LABEL org.opencontainers.image.description="Prometheus node exporter for host system metrics (CPU, memory, disk, network)"
LABEL org.opencontainers.image.vendor="accuser"

# Health check using the metrics endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:9100/metrics || exit 1

# Default entrypoint from upstream image
# Container expects host paths mounted:
#   --path.rootfs=/host (for filesystem metrics)
#   --path.procfs=/host/proc (for process metrics)
#   --path.sysfs=/host/sys (for system metrics)
