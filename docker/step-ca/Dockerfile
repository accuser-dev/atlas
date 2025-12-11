# Step-CA - Internal ACME Certificate Authority
# Provides automated certificate management for internal services
FROM smallstep/step-ca:0.28.4

# Labels for container identification
LABEL org.opencontainers.image.source="https://github.com/accuser-dev/atlas"
LABEL org.opencontainers.image.description="Internal ACME CA for Atlas infrastructure"
LABEL org.opencontainers.image.licenses="MIT"

# Copy initialization script
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Environment variables for CA configuration
# These can be overridden at runtime
ENV STEPCA_NAME="Atlas Internal CA"
ENV STEPCA_DNS="step-ca.incus,localhost"
ENV STEPCA_ADDRESS=":9000"
ENV STEPCA_PROVISIONER="acme"
ENV STEPCA_ROOT_DURATION="87600h"
ENV STEPCA_CERT_DURATION="24h"

# step-ca uses /home/step as its working directory
WORKDIR /home/step

# Expose ACME endpoint
EXPOSE 9000

# Health check - verify CA is responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt || exit 1

# Use custom entrypoint that initializes CA if needed
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
