# =============================================================================
# Incus Network Zone Module
# =============================================================================
# Creates a network zone for automatic DNS registration of containers.
# Supports zone transfer (AXFR) to external DNS servers like CoreDNS.
#
# Incus automatically creates A/AAAA records for:
#   - <instance>.<zone> - Container IPv4/IPv6 addresses
#   - <network>.gw.<zone> - Network gateway addresses
#
# Networks must be linked to the zone via dns.zone.forward configuration.

locals {
  # Build peer configuration for cross-environment Incus servers
  incus_peer_config = {
    for name, peer in var.peers : "peers.${name}.address" => peer.address
  }

  # Build peer configuration for DNS servers allowed to request zone transfers
  # These are external DNS servers (like CoreDNS) that pull the zone via AXFR
  transfer_peer_config = {
    for name, address in var.transfer_peers : "peers.${name}.address" => address
  }

  # Merge both peer configurations
  all_peer_config = merge(local.incus_peer_config, local.transfer_peer_config)
}

# =============================================================================
# Network Zone
# =============================================================================

resource "incus_network_zone" "this" {
  name        = var.zone_name
  description = var.description

  config = local.all_peer_config
}

# =============================================================================
# Custom Zone Records
# =============================================================================
# Useful for adding manual entries like CNAME aliases or external services

resource "incus_network_zone_record" "custom" {
  for_each = { for r in var.custom_records : r.name => r }

  zone        = incus_network_zone.this.name
  name        = each.value.name
  description = each.value.description

  dynamic "entry" {
    for_each = each.value.entries
    content {
      type  = entry.value.type
      value = entry.value.value
      ttl   = coalesce(entry.value.ttl, var.default_ttl)
    }
  }
}

# =============================================================================
# Incus DNS Server Configuration
# =============================================================================
# Configures core.dns_address to enable the Incus DNS server.
# This is required for zone transfers (AXFR) to external DNS servers.
#
# IMPORTANT: The DNS server only supports AXFR zone transfers, not direct queries.
# You must use an external DNS server (CoreDNS, BIND, etc.) for authoritative responses.

resource "incus_server" "dns_config" {
  count = var.configure_dns_server ? 1 : 0

  config = {
    "core.dns_address" = var.dns_listen_address
  }
}
