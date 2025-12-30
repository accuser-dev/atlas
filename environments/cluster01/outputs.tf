# =============================================================================
# Cluster Nodes
# =============================================================================

output "cluster_nodes" {
  description = "List of cluster node names (discovered from Incus API)"
  value       = local.cluster_nodes
}

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

# =============================================================================
# Log Shipping
# =============================================================================

output "alloy_endpoint" {
  description = "Alloy HTTP API endpoint URL"
  value       = module.alloy01.alloy_endpoint
}

output "alloy_loki_target" {
  description = "Loki URL that Alloy is shipping logs to"
  value       = module.alloy01.loki_target
}

output "alloy_syslog_endpoint" {
  description = "Syslog receiver endpoint (UDP) - configure IncusOS hosts to send logs here"
  value       = module.alloy01.syslog_endpoint
}

# =============================================================================
# OVN Configuration
# =============================================================================

output "cluster_ips" {
  description = "List of cluster node IP addresses (discovered from Incus API)"
  value       = local.cluster_ips
}

output "ovn_central_ipv4_address" {
  description = "IPv4 address of the OVN Central container"
  value       = var.network_backend == "ovn" ? module.ovn_central[0].ipv4_address : null
}

output "ovn_central_northbound_connection" {
  description = "OVN northbound connection string (points to ovn-central container)"
  value       = var.network_backend == "ovn" ? module.ovn_central[0].northbound_connection : null
}

output "ovn_central_southbound_connection" {
  description = "OVN southbound connection string (for chassis configuration)"
  value       = var.network_backend == "ovn" ? module.ovn_central[0].southbound_connection : null
}

output "network_backend" {
  description = "Network backend in use (bridge or ovn)"
  value       = var.network_backend
}

# =============================================================================
# OVN Load Balancer VIPs
# =============================================================================

output "mosquitto_lb_address" {
  description = "OVN load balancer VIP for Mosquitto (LAN-routable)"
  value       = var.network_backend == "ovn" && var.mosquitto_lb_address != "" ? var.mosquitto_lb_address : null
}

output "coredns_lb_address" {
  description = "OVN load balancer VIP for CoreDNS (LAN-routable)"
  value       = var.network_backend == "ovn" && var.coredns_lb_address != "" ? var.coredns_lb_address : null
}

output "alloy_syslog_lb_address" {
  description = "OVN load balancer VIP for Alloy syslog receiver (LAN-routable, UDP:1514)"
  value       = var.network_backend == "ovn" && var.alloy_syslog_lb_address != "" ? var.alloy_syslog_lb_address : null
}
