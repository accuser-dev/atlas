output "instance_name" {
  description = "Name of the Dex container instance"
  value       = incus_instance.dex.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.dex.name
}

output "instance_status" {
  description = "Status of the Dex container instance"
  value       = incus_instance.dex.status
}

output "ipv4_address" {
  description = "IPv4 address of the Dex instance"
  value       = incus_instance.dex.ipv4_address
}

output "issuer_url" {
  description = "The OIDC issuer URL for clients to use"
  value       = var.issuer_url
}

output "http_endpoint" {
  description = "HTTP endpoint URL for Dex"
  value       = "http://${incus_instance.dex.name}.incus:${var.http_port}"
}

output "metrics_endpoint" {
  description = "Prometheus metrics endpoint URL"
  value       = "http://${incus_instance.dex.name}.incus:${var.metrics_port}/metrics"
}

output "discovery_url" {
  description = "OIDC discovery endpoint (well-known configuration)"
  value       = "${var.issuer_url}/.well-known/openid-configuration"
}

output "dns_records" {
  description = "DNS records for this Dex instance (for CoreDNS zone file generation)"
  value = [
    {
      name  = "dex"
      type  = "A"
      value = incus_instance.dex.ipv4_address
      ttl   = 300
    }
  ]
}
