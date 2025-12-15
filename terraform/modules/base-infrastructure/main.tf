# =============================================================================
# Networks
# =============================================================================

# Production network - supports both bridge (NAT) and physical (direct LAN) modes
# Bridge mode: NAT'd network for standard deployments
# Physical mode: Direct LAN attachment for IncusOS clusters
resource "incus_network" "production" {
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
  }
}

resource "incus_network" "management" {
  name        = "management"
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

resource "incus_network" "gitops" {
  count = var.enable_gitops ? 1 : 0

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
      network = incus_network.production.name
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
      network = incus_network.management.name
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
      network = incus_network.gitops[0].name
    }
  }
}
