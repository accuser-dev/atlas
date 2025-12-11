# Node Exporter for host-level metrics collection
# Pinned to v1.10.2 for reproducibility
FROM prom/node-exporter:v1.10.2

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Node Exporter for host-level metrics collection"
LABEL org.opencontainers.image.source="https://github.com/accuser-dev/atlas"
LABEL org.opencontainers.image.version="1.10.2"
LABEL org.opencontainers.image.title="Atlas Node Exporter"
LABEL org.opencontainers.image.description="Prometheus node exporter for host system metrics (CPU, memory, disk, network)"
LABEL org.opencontainers.image.vendor="accuser"

# Health check using the metrics endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:9100/metrics || exit 1

# Configure node_exporter to use mounted host paths
# The Terraform module mounts:
#   / -> /host (host root filesystem)
#   /proc -> /host/proc (process info)
#   /sys -> /host/sys (system info)
ENTRYPOINT ["/bin/node_exporter"]
CMD ["--path.rootfs=/host", "--path.procfs=/host/proc", "--path.sysfs=/host/sys"]
