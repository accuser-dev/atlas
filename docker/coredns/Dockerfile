# CoreDNS for internal split-horizon DNS
# Provides authoritative DNS for internal zones with upstream forwarding
FROM coredns/coredns:1.12.0

# OCI metadata labels
LABEL maintainer="hello@accuser.dev"
LABEL description="CoreDNS for internal split-horizon DNS resolution"
LABEL org.opencontainers.image.source="https://github.com/accuser-dev/atlas"
LABEL org.opencontainers.image.version="1.12.0"
LABEL org.opencontainers.image.title="Atlas CoreDNS"
LABEL org.opencontainers.image.description="Split-horizon DNS server for internal service resolution"
LABEL org.opencontainers.image.vendor="accuser"

# Create configuration directories
# Incus file injection requires parent directories to exist
RUN mkdir -p /etc/coredns/zones

# Health check using the built-in health endpoint
# CoreDNS health plugin listens on a separate port (configured in Corefile)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://localhost:8080/health || exit 1

# Configuration is injected at /etc/coredns/ via Terraform
# - /etc/coredns/Corefile - Main configuration
# - /etc/coredns/zones/<domain>.zone - Zone files

# Default entrypoint from base image
# Override config path to use our mounted configuration
ENTRYPOINT ["/coredns"]
CMD ["-conf", "/etc/coredns/Corefile"]
