# CoreDNS for internal split-horizon DNS
# Provides authoritative DNS for internal zones with upstream forwarding
#
# Uses coredns package from Alpine testing repo to ensure proper LXC compatibility

FROM alpine:3.21

# OCI metadata labels
LABEL maintainer="hello@accuser.dev"
LABEL description="CoreDNS for internal split-horizon DNS resolution"
LABEL org.opencontainers.image.source="https://github.com/accuser-dev/atlas"
LABEL org.opencontainers.image.version="1.12.0"
LABEL org.opencontainers.image.title="Atlas CoreDNS"
LABEL org.opencontainers.image.description="Split-horizon DNS server for internal service resolution"
LABEL org.opencontainers.image.vendor="accuser"

# Install coredns from community repo and wget for health checks
# Using Alpine's package ensures proper integration with the system
RUN apk add --no-cache coredns wget

# Create configuration directories for Incus file injection
RUN mkdir -p /etc/coredns/zones

# Health check using the built-in health endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://localhost:8080/health || exit 1

# Configuration is injected at /etc/coredns/ via Terraform
# - /etc/coredns/Corefile - Main configuration
# - /etc/coredns/zones/<domain>.zone - Zone files

# Expose DNS ports (UDP and TCP) and metrics
EXPOSE 53/udp 53/tcp 9153/tcp 8080/tcp

ENTRYPOINT ["/usr/sbin/coredns"]
CMD ["-conf", "/etc/coredns/Corefile"]
