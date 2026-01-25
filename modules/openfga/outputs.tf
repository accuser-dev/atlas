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

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "ansible_vars" {
  description = "Variables to pass to Ansible for OpenFGA configuration"
  sensitive   = true
  value = {
    openfga_version           = var.openfga_version
    openfga_http_port         = var.http_port
    openfga_grpc_port         = var.grpc_port
    openfga_metrics_port      = var.metrics_port
    openfga_playground_port   = var.playground_port
    openfga_enable_playground = var.playground_port != ""
    # preshared_keys via env var OPENFGA_PRESHARED_KEYS at runtime
  }
}

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.openfga.name
    ipv4_address = incus_instance.openfga.ipv4_address
  }
}
