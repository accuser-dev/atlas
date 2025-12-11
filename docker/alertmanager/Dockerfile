# Custom Alertmanager with TLS support via step-ca
# Pinned to v0.28.0 for reproducibility and security
# Note: v0.27.0 has critical CVEs (CVE-2024-45337, CVE-2024-24790)
FROM prom/alertmanager:v0.28.0 AS base

# Build stage: Download step CLI
FROM alpine:3.22 AS step-cli
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

# TLS configuration directory
USER root
RUN mkdir -p /etc/alertmanager/tls && \
    chown -R nobody:nobody /etc/alertmanager/tls
USER nobody

# Environment variables for TLS (disabled by default)
ENV ENABLE_TLS="false"
ENV STEPCA_URL=""
ENV STEPCA_FINGERPRINT=""
ENV CERT_DURATION="24h"
ENV CERT_RENEW_BEFORE="1h"

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Alertmanager with TLS support via step-ca"
LABEL org.opencontainers.image.source="https://github.com/accuser-dev/atlas"
LABEL org.opencontainers.image.version="0.28.0"
LABEL org.opencontainers.image.title="Atlas Alertmanager"
LABEL org.opencontainers.image.description="Alertmanager for alert routing and notification management with TLS support"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /alertmanager

# Health check - supports both HTTP and HTTPS based on TLS mode
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD if [ "$ENABLE_TLS" = "true" ]; then \
        wget --no-verbose --tries=1 --spider --no-check-certificate https://localhost:9093/-/ready; \
      else \
        wget --no-verbose --tries=1 --spider http://localhost:9093/-/ready; \
      fi || exit 1

# Use TLS-aware entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint-tls.sh"]
