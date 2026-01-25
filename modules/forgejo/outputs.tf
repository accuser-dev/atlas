# =============================================================================
# Instance Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the Forgejo container instance"
  value       = incus_instance.forgejo.name
}

output "instance_status" {
  description = "Status of the Forgejo container"
  value       = incus_instance.forgejo.status
}

output "ipv4_address" {
  description = "IPv4 address of the Forgejo container"
  value       = incus_instance.forgejo.ipv4_address
}

output "profile_name" {
  description = "Name of the created Incus profile"
  value       = incus_profile.forgejo.name
}

# =============================================================================
# Storage Outputs
# =============================================================================

output "storage_volume_name" {
  description = "Name of the data storage volume (if enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.forgejo_data[0].name : null
}

# =============================================================================
# Service Endpoints
# =============================================================================

output "http_port" {
  description = "HTTP port for web UI"
  value       = var.http_port
}

output "http_endpoint" {
  description = "Forgejo web UI endpoint"
  value       = "${local.default_scheme}://${incus_instance.forgejo.name}.incus:${var.http_port}"
}

output "http_endpoint_ip" {
  description = "Forgejo web UI endpoint using IP address"
  value       = "${local.default_scheme}://${incus_instance.forgejo.ipv4_address}:${var.http_port}"
}

output "root_url" {
  description = "Configured root URL for Forgejo"
  value       = local.root_url
}

# =============================================================================
# SSH Outputs
# =============================================================================

output "ssh_port" {
  description = "SSH port for git operations"
  value       = var.enable_ssh_access ? var.ssh_port : null
}

output "ssh_endpoint" {
  description = "SSH endpoint for git clone (internal)"
  value       = var.enable_ssh_access ? "ssh://git@${incus_instance.forgejo.name}.incus:${var.ssh_port}" : null
}

output "ssh_clone_url" {
  description = "SSH clone URL format (git@host:owner/repo.git)"
  value       = var.enable_ssh_access ? "git@${incus_instance.forgejo.name}.incus" : null
}

output "external_ssh_port" {
  description = "External SSH port (if external SSH is enabled)"
  value       = var.enable_external_ssh ? var.external_ssh_port : null
}

# =============================================================================
# Metrics Outputs
# =============================================================================

output "metrics_endpoint" {
  description = "Prometheus metrics endpoint (if enabled)"
  value       = var.enable_metrics ? "${local.default_scheme}://${incus_instance.forgejo.name}.incus:${var.http_port}/metrics" : null
}

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.forgejo.name
    ipv4_address = incus_instance.forgejo.ipv4_address
  }
}

output "ansible_vars" {
  description = "Variables passed to Ansible for Forgejo configuration"
  sensitive   = true
  value = {
    forgejo_version       = var.forgejo_version
    forgejo_domain        = var.domain
    forgejo_root_url      = local.root_url
    forgejo_app_name      = var.app_name
    forgejo_http_port     = var.http_port
    forgejo_ssh_port      = var.ssh_port
    forgejo_enable_ssh    = var.enable_ssh_access
    forgejo_database_type = var.database_type
    forgejo_database_host = var.database_host
    forgejo_database_port = var.database_port
    forgejo_database_name = var.database_name
    forgejo_database_user = var.database_user
    # Note: database_password passed via environment variable at runtime
    forgejo_admin_username = var.admin_username
    forgejo_admin_email    = var.admin_email
    # Note: admin_password passed via environment variable at runtime
    forgejo_enable_tls     = var.enable_tls
    forgejo_tls_cert       = var.tls_certificate
    forgejo_tls_key        = var.tls_private_key
    forgejo_enable_metrics = var.enable_metrics
    forgejo_metrics_token  = var.metrics_token
  }
}
