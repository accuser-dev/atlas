# =============================================================================
# Networks
# =============================================================================
# Supports three network backends:
# - bridge: Traditional bridge networks (NAT) - default
# - physical: Direct LAN attachment for IncusOS clusters
# - ovn: OVN overlay networks for cross-environment connectivity

# =============================================================================
# Bridge/Physical Networks (when network_backend != "ovn")
# =============================================================================

# Production network - supports both bridge (NAT) and physical (direct LAN) modes
# Bridge mode: NAT'd network for standard deployments
# Physical mode: Direct LAN attachment for IncusOS clusters
#
# For physical networks (especially on clusters), the network typically already
# exists and is managed by IncusOS. We import it and ignore config changes.
resource "incus_network" "production" {
  count = var.network_backend != "ovn" ? 1 : 0

  name        = var.production_network_name
  description = var.production_network_type == "physical" ? "Production network (physical LAN attachment via ${var.production_network_parent})" : "Production network for public-facing services"
  type        = var.production_network_type

  # Config varies based on network type
  config = var.production_network_type == "physical" ? {
    # Physical network only needs parent interface
    parent = var.production_network_parent
    } : merge(
    # Bridge network needs IPv4/IPv6 configuration
    {
      "ipv4.address" = var.production_network_ipv4
      "ipv4.nat"     = tostring(var.production_network_nat)
    },
    var.production_network_ipv6 != "" ? {
      "ipv6.address" = var.production_network_ipv6
      "ipv6.nat"     = tostring(var.production_network_ipv6_nat)
      } : {
      "ipv6.address" = "none"
    }
  )

  lifecycle {
    precondition {
      condition     = var.production_network_type != "physical" || var.production_network_parent != ""
      error_message = "production_network_parent is required when production_network_type is 'physical'."
    }
    # For physical networks, ignore config changes as the network is managed externally
    # This avoids provider quirks with physical network config attributes
    ignore_changes = [config, description]
  }
}

# Management network - created only if not using an external network or OVN
# For clusters, use management_network_external=true and point to incusbr0
resource "incus_network" "management" {
  count = var.network_backend != "ovn" && !var.management_network_external ? 1 : 0

  name        = var.management_network_name
  description = "Management network for internal services (monitoring, etc.)"
  type        = "bridge"

  config = merge(
    {
      "ipv4.address" = var.management_network_ipv4
      "ipv4.nat"     = tostring(var.management_network_nat)
    },
    var.management_network_ipv6 != "" ? {
      "ipv6.address" = var.management_network_ipv6
      "ipv6.nat"     = tostring(var.management_network_ipv6_nat)
      } : {
      "ipv6.address" = "none"
    }
  )
}

# Data source to reference an existing management network (for clusters with bridge backend)
data "incus_network" "management_external" {
  count = var.network_backend != "ovn" && var.management_network_external ? 1 : 0
  name  = var.management_network_name
}

resource "incus_network" "gitops" {
  count = var.network_backend != "ovn" && var.enable_gitops ? 1 : 0

  name        = "gitops"
  description = "GitOps network for Atlantis and CI/CD automation"
  type        = "bridge"

  config = merge(
    {
      "ipv4.address" = var.gitops_network_ipv4
      "ipv4.nat"     = tostring(var.gitops_network_nat)
    },
    var.gitops_network_ipv6 != "" ? {
      "ipv6.address" = var.gitops_network_ipv6
      "ipv6.nat"     = tostring(var.gitops_network_ipv6_nat)
      } : {
      "ipv6.address" = "none"
    }
  )
}

# =============================================================================
# OVN Networks (when network_backend == "ovn")
# =============================================================================
# OVN provides overlay networking for cross-environment connectivity.
# Requires OVN central and uplink network to be configured beforehand.

# OVN Production Network - overlay network for public-facing services
resource "incus_network" "ovn_production" {
  count = var.network_backend == "ovn" ? 1 : 0

  name        = "ovn-production"
  description = "OVN production network for public-facing services"
  type        = "ovn"

  config = {
    "network"      = var.ovn_uplink_network
    "bridge.mtu"   = "1442"
    "ipv4.address" = var.production_network_ipv4
    "ipv4.nat"     = tostring(var.production_network_nat)
    "ipv4.dhcp"    = "true"
  }
}

# OVN Management Network - overlay network for internal services
resource "incus_network" "ovn_management" {
  count = var.network_backend == "ovn" ? 1 : 0

  name        = "ovn-management"
  description = "OVN management network for internal services (monitoring, etc.)"
  type        = "ovn"

  config = {
    "network"      = var.ovn_uplink_network
    "bridge.mtu"   = "1442"
    "ipv4.address" = var.management_network_ipv4
    "ipv4.nat"     = tostring(var.management_network_nat)
    "ipv4.dhcp"    = "true"
  }
}

# OVN GitOps Network - overlay network for CI/CD automation
resource "incus_network" "ovn_gitops" {
  count = var.network_backend == "ovn" && var.enable_gitops ? 1 : 0

  name        = "ovn-gitops"
  description = "OVN GitOps network for Atlantis and CI/CD automation"
  type        = "ovn"

  config = {
    "network"      = var.ovn_uplink_network
    "bridge.mtu"   = "1442"
    "ipv4.address" = var.gitops_network_ipv4
    "ipv4.nat"     = tostring(var.gitops_network_nat)
    "ipv4.dhcp"    = "true"
  }
}

# =============================================================================
# Network Selection Locals
# =============================================================================
# These locals select the correct network based on the backend type

locals {
  # Production network - use OVN or bridge/physical
  production_network_name = (
    var.network_backend == "ovn"
    ? incus_network.ovn_production[0].name
    : incus_network.production[0].name
  )

  # Management network - use OVN, external, or created bridge
  management_network_name = (
    var.network_backend == "ovn"
    ? incus_network.ovn_management[0].name
    : var.management_network_external
    ? data.incus_network.management_external[0].name
    : incus_network.management[0].name
  )

  # GitOps network - use OVN or bridge (null if not enabled)
  gitops_network_name = (
    var.enable_gitops
    ? (var.network_backend == "ovn"
      ? incus_network.ovn_gitops[0].name
    : incus_network.gitops[0].name)
    : null
  )
}

# =============================================================================
# Base Profiles
# =============================================================================

# Base profile for all containers (OCI and system containers)
# Provides: boot.autorestart only
# Root disk is defined per-service module to allow size limits
resource "incus_profile" "container_base" {
  name = "container-base"

  config = {
    "boot.autorestart" = "true"
  }
}

# =============================================================================
# Network Profiles
# =============================================================================

# Profile for containers on the production network
resource "incus_profile" "production_network" {
  name = "production-network"

  device {
    name = "prod"
    type = "nic"
    properties = {
      network = local.production_network_name
    }
  }
}

# Profile for containers on the management network
resource "incus_profile" "management_network" {
  name = "management-network"

  device {
    name = "mgmt"
    type = "nic"
    properties = {
      network = local.management_network_name
    }
  }
}

# Profile for containers on the GitOps network
resource "incus_profile" "gitops_network" {
  count = var.enable_gitops ? 1 : 0

  name = "gitops-network"

  device {
    name = "gitops"
    type = "nic"
    properties = {
      network = local.gitops_network_name
    }
  }
}
