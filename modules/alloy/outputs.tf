output "instance_name" {
  description = "Name of the Alloy instance"
  value       = incus_instance.alloy.name
}

output "profile_name" {
  description = "Name of the Alloy profile"
  value       = incus_profile.alloy.name
}

output "instance_status" {
  description = "Status of the Alloy instance"
  value       = incus_instance.alloy.status
}

output "ipv4_address" {
  description = "IPv4 address of the Alloy instance"
  value       = incus_instance.alloy.ipv4_address
}

output "ipv6_address" {
  description = "IPv6 address of the Alloy instance"
  value       = incus_instance.alloy.ipv6_address
}

output "alloy_endpoint" {
  description = "Alloy HTTP API endpoint"
  value       = "http://${incus_instance.alloy.name}.incus:${var.http_port}"
}

output "loki_target" {
  description = "Loki URL that Alloy is shipping logs to"
  value       = var.loki_push_url
}

output "syslog_endpoint" {
  description = "Syslog receiver endpoint (UDP) - configure IncusOS hosts to send logs here"
  value       = var.enable_syslog_receiver ? "${incus_instance.alloy.ipv4_address}:${var.syslog_port}" : null
}

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "ansible_vars" {
  description = "Variables to pass to Ansible for Alloy configuration"
  sensitive   = true
  value = {
    alloy_version          = var.alloy_version
    alloy_http_port        = var.http_port
    alloy_config_base64    = base64encode(local.alloy_config)
    alloy_has_config       = true
    enable_syslog_receiver = var.enable_syslog_receiver
    syslog_port            = var.syslog_port
  }
}

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.alloy.name
    ipv4_address = incus_instance.alloy.ipv4_address
  }
}
