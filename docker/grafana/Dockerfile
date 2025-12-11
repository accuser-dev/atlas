# Custom Grafana with TLS support via step-ca
# Pinned to v12.3.0 for reproducibility and security
FROM grafana/grafana:12.3.0 AS base

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

# Switch to root to install step CLI and configure TLS
USER root

# Copy step CLI from build stage
COPY --from=step-cli /usr/local/bin/step /usr/local/bin/step

# Copy TLS entrypoint script
COPY --chmod=755 entrypoint-tls.sh /usr/local/bin/entrypoint-tls.sh

# Create TLS directory with proper permissions
RUN mkdir -p /etc/grafana/tls && chown grafana:root /etc/grafana/tls

# Install Grafana plugins
# Uncomment and add plugins as needed:
# RUN grafana-cli plugins install grafana-piechart-panel
# RUN grafana-cli plugins install grafana-worldmap-panel
# RUN grafana-cli plugins install grafana-clock-panel

# Add custom provisioning configurations
# COPY provisioning/ /etc/grafana/provisioning/

# Environment variables for TLS (disabled by default)
ENV ENABLE_TLS="false"
ENV STEPCA_URL=""
ENV STEPCA_FINGERPRINT=""
ENV CERT_DURATION="24h"
ENV CERT_RENEW_BEFORE="1h"

# Switch back to grafana user for runtime security
USER grafana

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Grafana with TLS support via step-ca"
LABEL org.opencontainers.image.source="https://github.com/accuser-dev/atlas"
LABEL org.opencontainers.image.version="12.3.0"
LABEL org.opencontainers.image.title="Atlas Grafana"
LABEL org.opencontainers.image.description="Grafana visualization platform for monitoring stack with TLS support"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /usr/share/grafana

# Health check - supports both HTTP and HTTPS based on TLS mode
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD if [ "$ENABLE_TLS" = "true" ]; then \
        wget --no-verbose --tries=1 --spider --no-check-certificate https://localhost:3000/api/health; \
      else \
        wget --no-verbose --tries=1 --spider http://localhost:3000/api/health; \
      fi || exit 1

# Use TLS-aware entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint-tls.sh"]
