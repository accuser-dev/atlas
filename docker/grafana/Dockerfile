# Custom Grafana with pre-installed plugins
FROM grafana/grafana:latest

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

# Switch back to grafana user
USER grafana

LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Grafana with pre-installed plugins and configuration"
