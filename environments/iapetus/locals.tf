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

  # Dual-homed: management network (internal access, .incus DNS registration)
  # plus production network (direct LAN attachment via eno2 in physical mode).
  # Used by services that need to stay reachable internally by .incus name
  # (e.g. Prometheus scrape targets) while also getting a real LAN address.
  management_and_production_profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
    module.base.production_network_profile.name,
  ]

  gitops_profiles = var.enable_gitops ? [
    module.base.container_base_profile.name,
    module.base.gitops_network_profile.name,
  ] : []

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
    operations_center = {
      cpu    = "2"
      memory = "4GB"
      port   = 8443
    }
  }

  # NOTE: Network dependencies for depends_on cannot be centralized in locals
  # because Terraform requires static list expressions for depends_on.
  # See: https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on

  # Operations Center seed inputs shared with `make operations-center-iso`
  # (see Makefile) - kept in one file so the pinned NIC hwaddrs Terraform
  # applies to the instance and the ones baked into the install seed can
  # never drift apart. Contains no secrets. See
  # modules/operations-center/README.md for why these values must match
  # the already-installed instance's current volatile.<device>.hwaddr.
  operations_center_seed = jsondecode(file("${path.module}/operations-center-seed.json"))

  operations_center_network_interfaces = [
    for iface in local.operations_center_seed.interfaces : {
      device  = iface.device
      network = iface.device == "mgmt" ? module.base.management_network_name : module.base.production_network_name
      hwaddr  = iface.hwaddr
    }
  ]
}
