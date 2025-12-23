output "instance_name" {
  description = "Name of the OpenFGA container instance"
  value       = incus_instance.openfga.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.openfga.name
}

output "instance_status" {
  description = "Status of the OpenFGA container instance"
  value       = incus_instance.openfga.status
}

output "ipv4_address" {
  description = "IPv4 address of the OpenFGA instance"
  value       = incus_instance.openfga.ipv4_address
}

output "http_endpoint" {
  description = "HTTP API endpoint URL"
  value       = "http://${incus_instance.openfga.name}.incus:${var.http_port}"
}

output "grpc_endpoint" {
  description = "gRPC API endpoint"
  value       = "${incus_instance.openfga.name}.incus:${var.grpc_port}"
}

output "api_url" {
  description = "OpenFGA API URL for Incus configuration (openfga.api.url)"
  value       = "http://${incus_instance.openfga.name}.incus:${var.http_port}"
}

output "metrics_endpoint" {
  description = "Prometheus metrics endpoint URL"
  value       = "http://${incus_instance.openfga.name}.incus:${var.metrics_port}/metrics"
}

output "playground_endpoint" {
  description = "Playground web interface URL (if enabled)"
  value       = var.playground_port != "" ? "http://${incus_instance.openfga.name}.incus:${var.playground_port}" : null
}
