output "instance_name" {
  description = "Name of the step-ca instance"
  value       = incus_instance.step_ca.name
}

output "acme_endpoint" {
  description = "ACME endpoint URL for certificate requests"
  value       = "https://${var.instance_name}.incus:${var.acme_port}"
}

output "acme_directory" {
  description = "ACME directory URL for ACME clients"
  value       = "https://${var.instance_name}.incus:${var.acme_port}/acme/acme/directory"
}

output "root_ca_path" {
  description = "Path to root CA certificate inside the container"
  value       = "/home/step/certs/root_ca.crt"
}

output "ca_name" {
  description = "Name of the Certificate Authority"
  value       = var.ca_name
}
