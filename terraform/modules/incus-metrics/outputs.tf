output "metrics_certificate_pem" {
  description = "The metrics certificate in PEM format (for Prometheus tls_config.cert_file)"
  value       = tls_self_signed_cert.metrics.cert_pem
  sensitive   = true
}

output "metrics_private_key_pem" {
  description = "The metrics private key in PEM format (for Prometheus tls_config.key_file)"
  value       = tls_private_key.metrics.private_key_pem
  sensitive   = true
}

output "certificate_fingerprint" {
  description = "Fingerprint of the registered metrics certificate"
  value       = incus_certificate.metrics.fingerprint
}

output "incus_server_address" {
  description = "The Incus server address for metrics endpoint"
  value       = var.incus_server_address
}

output "server_name" {
  description = "Server name for TLS verification"
  value       = local.server_name
}

output "prometheus_scrape_config" {
  description = "Prometheus scrape configuration block for Incus metrics (YAML format)"
  value       = <<-EOT
    # Incus metrics
    - job_name: 'incus'
      metrics_path: '/1.0/metrics'
      scheme: 'https'
      scrape_interval: 15s
      static_configs:
        - targets: ['${var.incus_server_address}']
          labels:
            service: 'incus'
            instance: 'incus-host'
      tls_config:
        cert_file: '/etc/prometheus/tls/metrics.crt'
        key_file: '/etc/prometheus/tls/metrics.key'
        insecure_skip_verify: true
  EOT
}
