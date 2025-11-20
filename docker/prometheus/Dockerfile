# Custom Prometheus with pre-configured settings
FROM prom/prometheus:latest

# Add custom prometheus.yml if you want a default configuration
# Note: Terraform can also inject this configuration at runtime
# COPY prometheus.yml /etc/prometheus/prometheus.yml

# Add custom alert rules
# COPY alerts/ /etc/prometheus/alerts/

# Add custom recording rules
# COPY rules/ /etc/prometheus/rules/

LABEL maintainer="your-email@example.com"
LABEL description="Custom Prometheus with pre-configured rules and settings"
