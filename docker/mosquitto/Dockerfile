# Custom Mosquitto MQTT broker with TLS support via step-ca
# Pinned to v2.0.21 for reproducibility and security
FROM eclipse-mosquitto:2.0.21 AS base

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
RUN mkdir -p /mosquitto/tls && \
    chown -R mosquitto:mosquitto /mosquitto/tls

# Environment variables for TLS (disabled by default)
ENV ENABLE_TLS="false"
ENV STEPCA_URL=""
ENV STEPCA_FINGERPRINT=""
ENV CERT_DURATION="24h"
ENV CERT_RENEW_BEFORE="1h"

# MQTT port configuration
ENV MQTT_PORT="1883"
ENV MQTTS_PORT="8883"

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Mosquitto MQTT broker with TLS support via step-ca"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.version="2.0.21"
LABEL org.opencontainers.image.title="Atlas Mosquitto"
LABEL org.opencontainers.image.description="Eclipse Mosquitto MQTT broker for IoT messaging with TLS support"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /mosquitto

# Health check - check if mosquitto is accepting connections
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD mosquitto_sub -h localhost -p ${MQTT_PORT} -t '$SYS/broker/uptime' -C 1 -W 2 || exit 1

# Use TLS-aware entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint-tls.sh"]
