# locals.tf - Centralized configuration values
#
# This file contains common values used across multiple modules to:
# - Provide a single source of truth for shared configuration
# - Reduce copy-paste errors
# - Make it easier to update configurations across all modules

locals {
  # Project identification
  project_name = "atlas"

  # Image registry configuration
  # All custom images are published to GitHub Container Registry
  image_registry = "ghcr.io/accuser-dev/atlas"

  # Service configurations with default resource limits and ports
  # These can be overridden per-module if needed
  services = {
    caddy = {
      cpu    = "2"
      memory = "1GB"
      port   = 80
    }
    grafana = {
      cpu    = "2"
      memory = "1GB"
      port   = 3000
    }
    prometheus = {
      cpu    = "2"
      memory = "2GB"
      port   = 9090
    }
    loki = {
      cpu    = "2"
      memory = "2GB"
      port   = 3100
    }
    alertmanager = {
      cpu    = "1"
      memory = "256MB"
      port   = 9093
    }
    step_ca = {
      cpu    = "1"
      memory = "512MB"
      port   = 9000
    }
    node_exporter = {
      cpu    = "1"
      memory = "128MB"
      port   = 9100
    }
    mosquitto = {
      cpu    = "1"
      memory = "256MB"
      port   = 1883
    }
    cloudflared = {
      cpu    = "1"
      memory = "256MB"
      port   = 2000
    }
  }

  # NOTE: Network dependencies for depends_on cannot be centralized in locals
  # because Terraform requires static list expressions for depends_on.
  # See: https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on
}
