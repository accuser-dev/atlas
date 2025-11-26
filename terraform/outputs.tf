output "grafana_caddy_config" {
  description = "Generated Caddy configuration for Grafana"
  value       = module.grafana01.caddy_config_block
}

output "loki_endpoint" {
  description = "Loki endpoint URL for internal use (configure as Grafana data source)"
  value       = module.loki01.loki_endpoint
}

output "prometheus_endpoint" {
  description = "Prometheus endpoint URL for internal use (configure as Grafana data source)"
  value       = module.prometheus01.prometheus_endpoint
}

output "step_ca_acme_endpoint" {
  description = "step-ca ACME endpoint URL for certificate requests"
  value       = module.step_ca01.acme_endpoint
}

output "step_ca_acme_directory" {
  description = "step-ca ACME directory URL for ACME clients"
  value       = module.step_ca01.acme_directory
}

output "step_ca_fingerprint_command" {
  description = "Command to retrieve the CA fingerprint (run after deployment)"
  value       = module.step_ca01.fingerprint_command
}

output "node_exporter_endpoint" {
  description = "Node Exporter metrics endpoint URL for host monitoring"
  value       = module.node_exporter01.node_exporter_endpoint
}

output "alertmanager_endpoint" {
  description = "Alertmanager endpoint URL for alert routing"
  value       = module.alertmanager01.alertmanager_endpoint
}

output "mosquitto_mqtt_endpoint" {
  description = "Internal MQTT endpoint URL"
  value       = module.mosquitto01.mqtt_endpoint
}

output "mosquitto_external_ports" {
  description = "External host ports for MQTT access"
  value = {
    mqtt  = module.mosquitto01.external_mqtt_port
    mqtts = module.mosquitto01.external_mqtts_port
  }
}
