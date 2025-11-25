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
