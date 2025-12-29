# =============================================================================
# OVN Configuration Module
# =============================================================================
# Configures Incus daemon to connect to OVN infrastructure.
#
# PREREQUISITE: OVN must be enabled on the host(s) first via IncusOS service:
#   incus admin os service set ovn enabled=true database=cluster tunnel_address=<ip>
#
# This module manages the Incus daemon settings for OVN connectivity,
# NOT the underlying OVN infrastructure itself.

resource "incus_server" "ovn_config" {
  config = merge(
    {
      "network.ovn.northbound_connection" = var.northbound_connection
    },
    var.ca_cert != "" ? {
      "network.ovn.ca_cert" = var.ca_cert
    } : {},
    var.client_cert != "" ? {
      "network.ovn.client_cert" = var.client_cert
    } : {},
    var.client_key != "" ? {
      "network.ovn.client_key" = var.client_key
    } : {},
    var.integration_bridge != "" ? {
      "network.ovn.integration_bridge" = var.integration_bridge
    } : {}
  )
}
