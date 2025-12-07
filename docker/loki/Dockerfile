# Custom Loki with TLS support via step-ca
# Pinned to v3.6.1 for reproducibility and security
#
# Note: The official Loki image is scratch-based (no shell/tools).
# We use Alpine as base to enable TLS certificate management.

# Build stage: Download step CLI
FROM alpine:3.22 AS step-cli
ARG STEP_VERSION=0.28.6
RUN apk add --no-cache curl tar && \
    curl -sLO "https://github.com/smallstep/cli/releases/download/v${STEP_VERSION}/step_linux_${STEP_VERSION}_amd64.tar.gz" && \
    tar -xzf "step_linux_${STEP_VERSION}_amd64.tar.gz" && \
    mv "step_${STEP_VERSION}/bin/step" /usr/local/bin/step && \
    chmod +x /usr/local/bin/step

# Extract Loki binary from official image
FROM grafana/loki:3.6.2 AS loki-bin

# Final stage: Alpine-based image with shell support for TLS
FROM alpine:3.22

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata libcap

# Create loki user (matching official image UID)
RUN addgroup -g 10001 loki && \
    adduser -D -u 10001 -G loki loki

# Copy Loki binary from official image
COPY --from=loki-bin /usr/bin/loki /usr/bin/loki

# Copy step CLI from build stage
COPY --from=step-cli /usr/local/bin/step /usr/local/bin/step

# Copy TLS entrypoint script
COPY --chmod=755 entrypoint-tls.sh /usr/local/bin/entrypoint-tls.sh

# Create directories first (before copying config)
RUN mkdir -p /loki /etc/loki/tls

# Copy default Loki config
COPY --chmod=644 loki-config.yaml /etc/loki/loki-config.yaml

# Set proper permissions for loki user
RUN chown -R loki:loki /loki /etc/loki

# Environment variables for TLS (disabled by default)
ENV ENABLE_TLS="false"
ENV STEPCA_URL=""
ENV STEPCA_FINGERPRINT=""
ENV CERT_DURATION="24h"
ENV CERT_RENEW_BEFORE="1h"

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Loki with TLS support via step-ca"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.version="3.6.1"
LABEL org.opencontainers.image.title="Atlas Loki"
LABEL org.opencontainers.image.description="Loki log aggregation for internal monitoring stack with TLS support"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /loki

# Health check - supports both HTTP and HTTPS based on TLS mode
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD if [ "$ENABLE_TLS" = "true" ]; then \
        wget --no-verbose --tries=1 --spider --no-check-certificate https://localhost:3100/ready; \
      else \
        wget --no-verbose --tries=1 --spider http://localhost:3100/ready; \
      fi || exit 1

# Run as non-root user
USER loki

# Use TLS-aware entrypoint (includes YAML config generation fix)
ENTRYPOINT ["/usr/local/bin/entrypoint-tls.sh"]
