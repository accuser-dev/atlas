# =============================================================================
# Networks
# =============================================================================

resource "incus_network" "development" {
  name        = "development"
  description = "Development network"
  type        = "bridge"

  config = merge(
    {
      "ipv4.address" = var.development_network_ipv4
      "ipv4.nat"     = tostring(var.development_network_nat)
    },
    var.development_network_ipv6 != "" ? {
      "ipv6.address" = var.development_network_ipv6
      "ipv6.nat"     = tostring(var.development_network_ipv6_nat)
      } : {
      "ipv6.address" = "none"
    }
  )
}

resource "incus_network" "testing" {
  name        = "testing"
  description = "Testing network"
  type        = "bridge"

  config = merge(
    {
      "ipv4.address" = var.testing_network_ipv4
      "ipv4.nat"     = tostring(var.testing_network_nat)
    },
    var.testing_network_ipv6 != "" ? {
      "ipv6.address" = var.testing_network_ipv6
      "ipv6.nat"     = tostring(var.testing_network_ipv6_nat)
      } : {
      "ipv6.address" = "none"
    }
  )
}

resource "incus_network" "staging" {
  name        = "staging"
  description = "Staging network"
  type        = "bridge"

  config = merge(
    {
      "ipv4.address" = var.staging_network_ipv4
      "ipv4.nat"     = tostring(var.staging_network_nat)
    },
    var.staging_network_ipv6 != "" ? {
      "ipv6.address" = var.staging_network_ipv6
      "ipv6.nat"     = tostring(var.staging_network_ipv6_nat)
      } : {
      "ipv6.address" = "none"
    }
  )
}

resource "incus_network" "production" {
  name        = "production"
  description = "Production network"
  type        = "bridge"

  config = merge(
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

# Base profile for all Docker containers
# Provides: boot.autorestart, root disk
resource "incus_profile" "docker_base" {
  name = "docker-base"

  config = {
    "boot.autorestart" = "true"
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
    }
  }
}

# =============================================================================
# Network Profiles
# =============================================================================

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

# Profile for containers on the development network
resource "incus_profile" "development_network" {
  name = "development-network"

  device {
    name = "dev"
    type = "nic"
    properties = {
      network = incus_network.development.name
    }
  }
}

# Profile for containers on the testing network
resource "incus_profile" "testing_network" {
  name = "testing-network"

  device {
    name = "test"
    type = "nic"
    properties = {
      network = incus_network.testing.name
    }
  }
}

# Profile for containers on the staging network
resource "incus_profile" "staging_network" {
  name = "staging-network"

  device {
    name = "stage"
    type = "nic"
    properties = {
      network = incus_network.staging.name
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
