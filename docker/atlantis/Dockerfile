# Custom Atlantis with OpenTofu for GitOps workflow
# Pinned to v0.35.0 for reproducibility and security
FROM ghcr.io/runatlantis/atlantis:v0.39.0 AS base

# Final stage
FROM base

# Switch to root to install additional tools
USER root

# Install additional tools if needed
# OpenTofu is already included in the base image (v1.10.6)
# Add any custom tools here:
# RUN apk add --no-cache <package>

# Create custom scripts directory
RUN mkdir -p /home/atlantis/scripts && chown atlantis:atlantis /home/atlantis/scripts

# Copy custom configuration if needed
# COPY --chown=atlantis:atlantis repos.yaml /home/atlantis/repos.yaml
# COPY --chown=atlantis:atlantis atlantis.yaml /home/atlantis/atlantis.yaml

# Environment variables for Atlantis configuration
# These can be overridden at runtime via Terraform
ENV ATLANTIS_PORT="4141"
ENV ATLANTIS_DATA_DIR="/home/atlantis"
ENV ATLANTIS_DEFAULT_TF_VERSION="1.13.4"

# Switch back to atlantis user for runtime security
USER atlantis

# OCI metadata labels for container management
LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Atlantis for GitOps Terraform/OpenTofu workflow"
LABEL org.opencontainers.image.source="https://github.com/accuser-dev/atlas"
LABEL org.opencontainers.image.version="0.35.0"
LABEL org.opencontainers.image.title="Atlas Atlantis"
LABEL org.opencontainers.image.description="Atlantis GitOps server for Terraform/OpenTofu with PR automation"
LABEL org.opencontainers.image.vendor="accuser"

# Set working directory
WORKDIR /home/atlantis

# Health check using Atlantis healthz endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4141/healthz || exit 1

# Default entrypoint from base image
# ENTRYPOINT ["docker-entrypoint.sh"]
# CMD ["server"]
