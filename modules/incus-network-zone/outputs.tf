output "zone_name" {
  description = "Name of the created network zone"
  value       = incus_network_zone.this.name
}

output "dns_server_address" {
  description = "Address of the Incus DNS server for zone transfers"
  value       = var.configure_dns_server ? var.dns_listen_address : null
}

output "dns_reachable_address" {
  description = "Address where CoreDNS can reach the Incus DNS server"
  value       = var.dns_reachable_address != "" ? var.dns_reachable_address : var.dns_listen_address
}

output "zone_transfer_enabled" {
  description = "Whether zone transfer is enabled (DNS server configured)"
  value       = var.configure_dns_server
}

output "secondary_zone_config" {
  description = "Configuration for CoreDNS secondary zone"
  value = {
    zone   = incus_network_zone.this.name
    master = var.dns_reachable_address != "" ? var.dns_reachable_address : var.dns_listen_address
  }
}
