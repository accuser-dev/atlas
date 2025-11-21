# Custom Grafana with pre-installed plugins
# Pinned to v12.3.0 for reproducibility and security
FROM grafana/grafana:12.3.0

# Switch to root to install plugins
USER root

# Install Grafana plugins
# Uncomment and add plugins as needed:
# RUN grafana-cli plugins install grafana-piechart-panel
# RUN grafana-cli plugins install grafana-worldmap-panel
# RUN grafana-cli plugins install grafana-clock-panel

# Add custom provisioning configurations
# COPY provisioning/ /etc/grafana/provisioning/

# Add custom grafana.ini if needed
# COPY grafana.ini /etc/grafana/grafana.ini

# Switch back to grafana user for runtime security
USER grafana

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Grafana with pre-installed plugins and configuration"
LABEL org.opencontainers.image.source="https://github.com/accuser/atlas"
LABEL org.opencontainers.image.version="12.3.0"
LABEL org.opencontainers.image.title="Atlas Grafana"
LABEL org.opencontainers.image.description="Grafana visualization platform for monitoring stack"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /usr/share/grafana

# Health check to verify Grafana is running and responding
# Checks the health endpoint which returns 200 when Grafana is operational
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1
