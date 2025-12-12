# Outputs for caddy-gitops module

output "instance_name" {
  description = "Name of the Caddy GitOps instance"
  value       = incus_instance.caddy_gitops.name
}

output "instance_status" {
  description = "Status of the Caddy GitOps instance"
  value       = incus_instance.caddy_gitops.status
}

output "ipv4_address" {
  description = "IPv4 address of the Caddy GitOps instance"
  value       = incus_instance.caddy_gitops.ipv4_address
}

output "metrics_endpoint" {
  description = "Caddy GitOps admin API endpoint for Prometheus metrics"
  value       = "http://${incus_instance.caddy_gitops.name}.incus:2019/metrics"
}
