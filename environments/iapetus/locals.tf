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

  # ==========================================================================
  # Common Profile Sets (Phase 2: Reduce duplication)
  # ==========================================================================
  # Standard profile combinations used by service modules

  management_profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  production_profiles = [
    module.base.container_base_profile.name,
    module.base.production_network_profile.name,
  ]

  gitops_profiles = var.enable_gitops ? [
    module.base.container_base_profile.name,
    module.base.gitops_network_profile.name,
  ] : []

  # ==========================================================================
  # External Access Logic (Phase 2: Reduce duplication)
  # ==========================================================================
  # Common conditions for external access configuration

  bridge_external_access = var.network_backend == "bridge" && !module.base.production_network_is_physical
  use_ovn_lb             = var.network_backend == "ovn"

  # ==========================================================================
  # OVN Load Balancer Configuration
  # ==========================================================================
  ovn_load_balancers = {
    grafana = {
      enabled        = var.grafana_lb_address != ""
      network        = "management"
      listen_address = var.grafana_lb_address
      description    = "Grafana dashboard"
      backends = [{
        name           = "grafana01"
        target_address = module.grafana01.ipv4_address
        target_port    = 3000
      }]
      ports        = [{ description = "HTTP", protocol = "tcp", listen_port = 3000, target_backends = null }]
      health_check = { enabled = true }
    }
    prometheus = {
      enabled        = var.prometheus_lb_address != ""
      network        = "management"
      listen_address = var.prometheus_lb_address
      description    = "Prometheus metrics server"
      backends = [{
        name           = "prometheus01"
        target_address = module.prometheus01.ipv4_address
        target_port    = 9090
      }]
      ports        = [{ description = "HTTP", protocol = "tcp", listen_port = 9090, target_backends = null }]
      health_check = { enabled = true }
    }
    loki = {
      enabled        = var.loki_lb_address != ""
      network        = "management"
      listen_address = var.loki_lb_address
      description    = "Loki log aggregator"
      backends = [{
        name           = "loki01"
        target_address = module.loki01.ipv4_address
        target_port    = 3100
      }]
      ports        = [{ description = "HTTP", protocol = "tcp", listen_port = 3100, target_backends = null }]
      health_check = { enabled = true }
    }
    step_ca = {
      enabled        = var.step_ca_lb_address != ""
      network        = "management"
      listen_address = var.step_ca_lb_address
      description    = "step-ca ACME server"
      backends = [{
        name           = "step-ca01"
        target_address = module.step_ca01.ipv4_address
        target_port    = 9000
      }]
      ports        = [{ description = "HTTPS", protocol = "tcp", listen_port = 9000, target_backends = null }]
      health_check = { enabled = true }
    }
    coredns = {
      enabled        = var.coredns_lb_address != ""
      network        = "production"
      listen_address = var.coredns_lb_address
      description    = "CoreDNS"
      backends = [{
        name           = "coredns01"
        target_address = module.coredns01.ipv4_address
        target_port    = 53
      }]
      ports = [
        { description = "DNS over UDP", protocol = "udp", listen_port = 53, target_backends = null },
        { description = "DNS over TCP", protocol = "tcp", listen_port = 53, target_backends = null },
      ]
      health_check = { enabled = true }
    }
    atlantis = {
      enabled        = var.atlantis_lb_address != "" && var.enable_gitops
      network        = "gitops"
      listen_address = var.atlantis_lb_address
      description    = "Atlantis GitOps server"
      backends = [{
        name           = "atlantis01"
        target_address = try(module.atlantis01[0].ipv4_address, "0.0.0.0")
        target_port    = 4141
      }]
      ports        = [{ description = "HTTP", protocol = "tcp", listen_port = 4141, target_backends = null }]
      health_check = { enabled = true }
    }
  }

  # ==========================================================================
  # Service Resource Limits
  # ==========================================================================
  # Service configurations with default resource limits and ports
  # These can be overridden per-module if needed
  services = {
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
    step_ca = {
      cpu    = "1"
      memory = "512MB"
      port   = 9000
    }
    cloudflared = {
      cpu    = "1"
      memory = "256MB"
      port   = 2000
    }
    atlantis = {
      cpu    = "2"
      memory = "1GB"
      port   = 4141
    }
    coredns = {
      cpu    = "1"
      memory = "128MB"
      port   = 53
    }
    dex = {
      cpu    = "1"
      memory = "128MB"
      port   = 5556
    }
    openfga = {
      cpu    = "1"
      memory = "256MB"
      port   = 8080
    }
    haproxy = {
      cpu    = "1"
      memory = "256MB"
      port   = 8443
    }
    ovn_central = {
      cpu    = "1"
      memory = "512MB"
      port   = 6641
    }
  }

  # NOTE: Network dependencies for depends_on cannot be centralized in locals
  # because Terraform requires static list expressions for depends_on.
  # See: https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on
}
