output "instance_name" {
  description = "Name of the Mosquitto container instance"
  value       = incus_instance.mosquitto.name
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
