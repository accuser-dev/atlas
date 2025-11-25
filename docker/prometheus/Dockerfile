# Custom Prometheus with TLS support via step-ca
# Pinned to v3.7.3 for reproducibility and security
FROM prom/prometheus:v3.7.3 AS base

# Build stage: Download step CLI
FROM alpine:3.21 AS step-cli
ARG STEP_VERSION=0.28.6
RUN apk add --no-cache curl tar && \
    curl -sLO "https://github.com/smallstep/cli/releases/download/v${STEP_VERSION}/step_linux_${STEP_VERSION}_amd64.tar.gz" && \
    tar -xzf "step_linux_${STEP_VERSION}_amd64.tar.gz" && \
    mv "step_${STEP_VERSION}/bin/step" /usr/local/bin/step && \
    chmod +x /usr/local/bin/step

# Final stage
FROM base

# Copy step CLI from build stage
COPY --from=step-cli /usr/local/bin/step /usr/local/bin/step

# Copy TLS entrypoint script
COPY --chmod=755 entrypoint-tls.sh /usr/local/bin/entrypoint-tls.sh

# TLS and alerts configuration directories
RUN mkdir -p /etc/prometheus/tls /etc/prometheus/alerts && \
    chown -R nobody:nobody /etc/prometheus/tls /etc/prometheus/alerts

# Environment variables for TLS (disabled by default)
ENV ENABLE_TLS="false"
ENV STEPCA_URL=""
ENV STEPCA_FINGERPRINT=""
ENV CERT_DURATION="24h"
ENV CERT_RENEW_BEFORE="1h"

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Prometheus with TLS support via step-ca"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.version="3.7.3"
LABEL org.opencontainers.image.title="Atlas Prometheus"
LABEL org.opencontainers.image.description="Prometheus metrics collection for internal monitoring stack with TLS support"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /prometheus

# Health check - supports both HTTP and HTTPS based on TLS mode
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD if [ "$ENABLE_TLS" = "true" ]; then \
        wget --no-verbose --tries=1 --spider --no-check-certificate https://localhost:9090/-/ready; \
      else \
        wget --no-verbose --tries=1 --spider http://localhost:9090/-/ready; \
      fi || exit 1

# Use TLS-aware entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint-tls.sh"]
