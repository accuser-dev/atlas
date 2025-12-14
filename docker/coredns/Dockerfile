# CoreDNS for internal split-horizon DNS
# Provides authoritative DNS for internal zones with upstream forwarding

# Build stage to create directory structure
# CoreDNS base image is scratch-based (no shell), so we need to create dirs here
FROM alpine:3.21 AS builder
RUN mkdir -p /etc/coredns/zones

# Final image
FROM coredns/coredns:1.12.0

# OCI metadata labels
LABEL maintainer="hello@accuser.dev"
LABEL description="CoreDNS for internal split-horizon DNS resolution"
LABEL org.opencontainers.image.source="https://github.com/accuser-dev/atlas"
LABEL org.opencontainers.image.version="1.12.0"
LABEL org.opencontainers.image.title="Atlas CoreDNS"
LABEL org.opencontainers.image.description="Split-horizon DNS server for internal service resolution"
LABEL org.opencontainers.image.vendor="accuser"

# Copy directory structure from builder
# This creates /etc/coredns/zones for Incus file injection
COPY --from=builder /etc/coredns /etc/coredns

# Note: HEALTHCHECK not supported on scratch-based images (no shell/wget)
# Health is monitored via CoreDNS health plugin endpoint instead

# Configuration is injected at /etc/coredns/ via Terraform
# - /etc/coredns/Corefile - Main configuration
# - /etc/coredns/zones/<domain>.zone - Zone files

# Default entrypoint from base image
# Override config path to use our mounted configuration
ENTRYPOINT ["/coredns"]
CMD ["-conf", "/etc/coredns/Corefile"]
