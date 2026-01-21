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

output "fingerprint_command" {
  description = "Command to retrieve the CA fingerprint after deployment"
  value       = "incus exec ${var.instance_name} -- cat /home/step/fingerprint"
}

output "fingerprint_file_path" {
  description = "Path to the fingerprint file inside the container"
  value       = "/home/step/fingerprint"
}

output "ipv4_address" {
  description = "IPv4 address of the step-ca instance"
  value       = incus_instance.step_ca.ipv4_address
}
