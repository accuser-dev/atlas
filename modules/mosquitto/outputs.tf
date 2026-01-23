output "instance_name" {
  description = "Name of the Mosquitto container instance"
  value       = incus_instance.mosquitto.name
}

output "profile_name" {
  description = "Name of the Mosquitto profile"
  value       = incus_profile.mosquitto.name
}

output "instance_status" {
  description = "Status of the Mosquitto instance"
  value       = incus_instance.mosquitto.status
}

output "storage_volume_name" {
  description = "Name of the storage volume (if data persistence is enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.mosquitto_data[0].name : null
}

output "mqtt_endpoint" {
  description = "Internal MQTT endpoint URL"
  value       = "mqtt://${incus_instance.mosquitto.name}.incus:${var.mqtt_port}"
}

output "mqtts_endpoint" {
  description = "Internal MQTTS endpoint URL (only available when TLS is enabled)"
  value       = var.enable_tls ? "mqtts://${incus_instance.mosquitto.name}.incus:${var.mqtts_port}" : ""
}

output "external_mqtt_port" {
  description = "Host port for external MQTT access"
  value       = var.enable_external_access ? var.external_mqtt_port : ""
}

output "external_mqtts_port" {
  description = "Host port for external MQTTS access (only available when TLS is enabled)"
  value       = var.enable_external_access && var.enable_tls ? var.external_mqtts_port : ""
}

output "tls_enabled" {
  description = "Whether TLS is enabled for the Mosquitto instance"
  value       = var.enable_tls
}

output "external_access_enabled" {
  description = "Whether external access is enabled via proxy devices"
  value       = var.enable_external_access
}

output "ipv4_address" {
  description = "IPv4 address of the Mosquitto container"
  value       = incus_instance.mosquitto.ipv4_address
}

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.mosquitto.name
    ipv4_address = incus_instance.mosquitto.ipv4_address
  }
}

output "ansible_vars" {
  description = "Variables passed to Ansible for Mosquitto configuration"
  sensitive   = true
  value = {
    mosquitto_mqtt_port  = var.mqtt_port
    mosquitto_mqtts_port = var.mqtts_port
    mosquitto_enable_tls = var.enable_tls
    mosquitto_users      = var.mqtt_users
    mosquitto_config     = var.mosquitto_config
    stepca_url           = var.stepca_url
    stepca_fingerprint   = var.stepca_fingerprint
    cert_duration        = var.cert_duration
    step_version         = var.step_version
  }
}
