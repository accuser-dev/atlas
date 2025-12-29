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
#
# KNOWN ISSUE: In clusters accessed via load balancer (e.g., HAProxy round-robin),
# the incus_server resource may fail with "ETag doesn't match" errors due to
# requests hitting different cluster nodes. Workarounds:
#   1. Set skip_ovn_config=true in the environment and configure via CLI:
#      incus config set network.ovn.northbound_connection=tcp:<ip>:6641
#   2. Configure the Incus remote to connect directly to a specific node
#   3. Retry the apply until it succeeds (not recommended)
#
# See: https://github.com/lxc/terraform-provider-incus/issues/139

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
