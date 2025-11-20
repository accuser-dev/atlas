resource "incus_network" "development" {
  name        = "development"
  description = "Development network"
  type        = "bridge"

  config = {
    "ipv4.address" = var.development_network_ipv4
    "ipv4.nat"     = var.development_network_nat
    "ipv6.address" = var.development_network_ipv6
    "ipv6.nat"     = var.development_network_ipv6_nat
  }
}

resource "incus_network" "testing" {
  name        = "testing"
  description = "Testing network"
  type        = "bridge"

  config = {
    "ipv4.address" = var.testing_network_ipv4
    "ipv4.nat"     = var.testing_network_nat
    "ipv6.address" = var.testing_network_ipv6
    "ipv6.nat"     = var.testing_network_ipv6_nat
  }
}

resource "incus_network" "production" {
  name        = "production"
  description = "Production network"
  type        = "bridge"

  config = {
    "ipv4.address" = var.production_network_ipv4
    "ipv4.nat"     = var.production_network_nat
    "ipv6.address" = var.production_network_ipv6
    "ipv6.nat"     = var.production_network_ipv6_nat
  }
}
