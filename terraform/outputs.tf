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

output "cloudflared_metrics_endpoint" {
  description = "Cloudflared metrics endpoint URL (if enabled)"
  value       = length(module.cloudflared01) > 0 ? module.cloudflared01[0].metrics_endpoint : null
}

output "cloudflared_instance_status" {
  description = "Cloudflared instance status (if enabled)"
  value       = length(module.cloudflared01) > 0 ? module.cloudflared01[0].instance_status : null
}

output "incus_metrics_endpoint" {
  description = "Incus metrics endpoint URL being scraped by Prometheus"
  value       = var.enable_incus_metrics ? "https://${var.incus_metrics_address}/1.0/metrics" : null
}

output "incus_metrics_certificate_fingerprint" {
  description = "Fingerprint of the metrics certificate registered with Incus"
  value       = var.enable_incus_metrics ? module.incus_metrics[0].certificate_fingerprint : null
}

output "incus_loki_logging_name" {
  description = "Name of the Incus logging configuration for Loki"
  value       = var.enable_incus_loki ? module.incus_loki[0].logging_name : null
}

output "incus_loki_address" {
  description = "Loki address configured for Incus logging"
  value       = var.enable_incus_loki ? module.incus_loki[0].loki_address : null
}

# Atlantis GitOps outputs
output "atlantis_webhook_endpoint" {
  description = "Atlantis webhook endpoint URL for GitHub webhooks"
  value       = var.enable_atlantis ? module.atlantis01[0].webhook_endpoint : null
}

output "atlantis_instance_status" {
  description = "Atlantis instance status (if enabled)"
  value       = var.enable_atlantis ? module.atlantis01[0].instance_status : null
}

output "atlantis_caddy_config" {
  description = "Generated Caddy configuration for Atlantis"
  value       = var.enable_atlantis ? module.atlantis01[0].caddy_config_block : null
}

output "caddy_gitops_instance_status" {
  description = "Caddy GitOps instance status (if enabled)"
  value       = var.enable_atlantis ? module.caddy_gitops01[0].instance_status : null
}

output "caddy_gitops_metrics_endpoint" {
  description = "Caddy GitOps metrics endpoint URL (if enabled)"
  value       = var.enable_atlantis ? module.caddy_gitops01[0].metrics_endpoint : null
}
