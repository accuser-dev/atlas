# =============================================================================
# OVN Load Balancer Module
# =============================================================================
# Creates an OVN network load balancer with configurable backends and ports.
# This replaces proxy devices for external service access when using OVN.
#
# The load balancer VIP must be within the uplink network's ipv4.ovn.ranges.
# For LAN-routable VIPs, ensure the VIP is outside the DHCP range.

locals {
  # Get all backend names for use as default target_backends
  all_backend_names = [for b in var.backends : b.name]

  # Build health check config map when enabled
  health_check_config = try(var.health_check.enabled, false) ? {
    "healthcheck"               = "true"
    "healthcheck.interval"      = tostring(try(var.health_check.interval, 10))
    "healthcheck.timeout"       = tostring(try(var.health_check.timeout, 30))
    "healthcheck.failure_count" = tostring(try(var.health_check.failure_count, 3))
    "healthcheck.success_count" = tostring(try(var.health_check.success_count, 3))
  } : {}
}

resource "incus_network_lb" "lb" {
  network        = var.network_name
  listen_address = var.listen_address
  description    = var.description
  config         = local.health_check_config

  dynamic "backend" {
    for_each = var.backends
    content {
      name           = backend.value.name
      description    = backend.value.description
      target_address = backend.value.target_address
      target_port    = backend.value.target_port
    }
  }

  dynamic "port" {
    for_each = var.ports
    content {
      description = port.value.description
      protocol    = port.value.protocol
      listen_port = port.value.listen_port
      # Use specified backends or default to all backends
      target_backend = port.value.target_backends != null ? port.value.target_backends : local.all_backend_names
    }
  }
}
