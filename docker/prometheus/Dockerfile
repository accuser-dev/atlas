# Custom Prometheus with pre-configured settings
# Pinned to v3.7.3 for reproducibility and security
FROM prom/prometheus:v3.7.3

# Add custom prometheus.yml if you want a default configuration
# Note: Terraform can also inject this configuration at runtime
# COPY prometheus.yml /etc/prometheus/prometheus.yml

# Add custom alert rules
# COPY alerts/ /etc/prometheus/alerts/

# Add custom recording rules
# COPY rules/ /etc/prometheus/rules/

LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Prometheus with pre-configured rules and settings"
