# =============================================================================
# Network Configuration
# =============================================================================

output "production_network_type" {
  description = "Production network type (bridge or physical)"
  value       = module.base.production_network_type
}

output "production_network_is_physical" {
  description = "Whether production network is physical (direct LAN attachment)"
  value       = module.base.production_network_is_physical
}

# =============================================================================
# Service Endpoints
# =============================================================================

output "prometheus_endpoint" {
  description = "Prometheus endpoint URL (for iapetus federation)"
  value       = module.prometheus01.prometheus_endpoint
}

output "alertmanager_endpoint" {
  description = "Alertmanager endpoint URL"
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

# =============================================================================
# DNS Configuration
# =============================================================================

output "coredns_dns_endpoint" {
  description = "Internal DNS endpoint"
  value       = module.coredns01.dns_endpoint
}

output "coredns_ipv4_address" {
  description = "CoreDNS IPv4 address"
  value       = module.coredns01.ipv4_address
}

output "coredns_external_port" {
  description = "External DNS port on host (bridge mode only)"
  value       = module.coredns01.external_dns_port
}

# =============================================================================
# Node Exporters
# =============================================================================

output "node_exporter_endpoints" {
  description = "Node exporter endpoints for each cluster node"
  value = {
    for node, exporter in module.node_exporter : node => exporter.node_exporter_endpoint
  }
}

# =============================================================================
# Incus Metrics
# =============================================================================

output "incus_metrics_endpoint" {
  description = "Incus metrics endpoint URL"
  value       = var.enable_incus_metrics ? "https://${var.incus_metrics_address}/1.0/metrics" : null
}

output "incus_metrics_certificate_fingerprint" {
  description = "Fingerprint of the metrics certificate"
  value       = var.enable_incus_metrics ? module.incus_metrics[0].certificate_fingerprint : null
}
