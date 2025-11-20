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
