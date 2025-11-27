module "caddy01" {
  source = "./modules/caddy"

  instance_name        = "caddy01"
  profile_name         = "caddy"
  cloudflare_api_token = var.cloudflare_api_token

  # Service blocks from all modules
  service_blocks = [
    module.grafana01.caddy_config_block,
    # Add more service blocks here as you create more modules
  ]

  # Network configuration - reference managed networks
  production_network = incus_network.production.name
  management_network = incus_network.management.name
  external_network   = "incusbr0"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.staging,
    incus_network.production,
    incus_network.management
  ]

  # Optional: Override defaults if needed
  # cpu_limit            = "2"
  # memory_limit         = "1GB"
  # storage_pool         = "default"
}

module "grafana01" {
  source = "./modules/grafana"

  instance_name = "grafana01"
  profile_name  = "grafana"

  # Network configuration - use management network for internal services
  network_name = incus_network.management.name

  # Domain configuration for reverse proxy
  domain           = "grafana.accuser.dev"
  allowed_ip_range = "192.168.68.0/22"
  grafana_port     = "3000"

  # Environment variables for Grafana configuration
  environment_variables = {
    GF_SECURITY_ADMIN_USER     = "admin"
    GF_SECURITY_ADMIN_PASSWORD = var.grafana_admin_password
    GF_SERVER_HTTP_PORT        = "3000"
  }

  # Configure datasources for Prometheus and Loki (derived from module outputs)
  datasources = [
    {
      name            = "Prometheus"
      type            = "prometheus"
      url             = module.prometheus01.prometheus_endpoint
      is_default      = true
      tls_skip_verify = module.prometheus01.tls_enabled # Skip verify for internal CA
    },
    {
      name            = "Loki"
      type            = "loki"
      url             = module.loki01.loki_endpoint
      is_default      = false
      tls_skip_verify = module.loki01.tls_enabled # Skip verify for internal CA
    }
  ]

  # Enable persistent storage for dashboards and data
  enable_data_persistence = true
  data_volume_name        = "grafana01-data"
  data_volume_size        = "10GB"

  # Resource limits
  cpu_limit    = "2"
  memory_limit = "1GB"

  # Ensure networks and dependencies are created
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.staging,
    incus_network.production,
    incus_network.management,
    module.prometheus01,
    module.loki01
  ]
}

module "loki01" {
  source = "./modules/loki"

  instance_name = "loki01"
  profile_name  = "loki"

  # Network configuration - use management network for internal services
  network_name = incus_network.management.name

  # Loki configuration
  loki_port = "3100"

  # Enable persistent storage for log data
  enable_data_persistence = true
  data_volume_name        = "loki01-data"
  data_volume_size        = "50GB"

  # Resource limits - Loki needs more memory for log processing
  cpu_limit    = "2"
  memory_limit = "2GB"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.staging,
    incus_network.production,
    incus_network.management
  ]
}

module "prometheus01" {
  source = "./modules/prometheus"

  instance_name = "prometheus01"
  profile_name  = "prometheus"

  # Network configuration - use management network for internal services
  network_name = incus_network.management.name

  # Prometheus configuration
  prometheus_port = "9090"

  # Prometheus configuration with health check monitoring
  prometheus_config = <<-EOT
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: 'atlas'
        environment: 'production'

    scrape_configs:
      # Prometheus self-monitoring
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
            labels:
              service: 'prometheus'
              instance: 'prometheus01'

      # Grafana metrics
      - job_name: 'grafana'
        static_configs:
          - targets: ['grafana01.incus:3000']
            labels:
              service: 'grafana'
              instance: 'grafana01'

      # Loki metrics
      - job_name: 'loki'
        static_configs:
          - targets: ['loki01.incus:3100']
            labels:
              service: 'loki'
              instance: 'loki01'

      # Caddy metrics (if metrics are enabled)
      - job_name: 'caddy'
        static_configs:
          - targets: ['caddy01.incus:2019']
            labels:
              service: 'caddy'
              instance: 'caddy01'

      # step-ca health monitoring
      - job_name: 'step-ca'
        metrics_path: '/health'
        static_configs:
          - targets: ['step-ca01.incus:9000']
            labels:
              service: 'step-ca'
              instance: 'step-ca01'

      # Node Exporter for host metrics
      - job_name: 'node'
        static_configs:
          - targets: ['node-exporter01.incus:9100']
            labels:
              service: 'node-exporter'
              instance: 'node-exporter01'

      # Incus container metrics (mTLS authentication required)
      - job_name: 'incus'
        metrics_path: '/1.0/metrics'
        scheme: 'https'
        static_configs:
          - targets: ['${var.incus_metrics_address}']
            labels:
              service: 'incus'
              instance: 'incus-host'
        tls_config:
          cert_file: '/etc/prometheus/tls/metrics.crt'
          key_file: '/etc/prometheus/tls/metrics.key'
          insecure_skip_verify: true

    # Alerting rules for infrastructure monitoring
    rule_files:
      - '/etc/prometheus/alerts/*.yml'

    alerting:
      alertmanagers:
        - static_configs:
            - targets: ['alertmanager01.incus:9093']
  EOT

  # Alert rules for OOM and container restart detection (optional)
  alert_rules = fileexists("${path.module}/prometheus-alerts.yml") ? file("${path.module}/prometheus-alerts.yml") : ""

  # Incus metrics certificate (for mTLS authentication to Incus API)
  incus_metrics_certificate = var.enable_incus_metrics ? module.incus_metrics[0].metrics_certificate_pem : ""
  incus_metrics_private_key = var.enable_incus_metrics ? module.incus_metrics[0].metrics_private_key_pem : ""

  # Enable persistent storage for metrics data
  enable_data_persistence = true
  data_volume_name        = "prometheus01-data"
  data_volume_size        = "100GB"

  # Resource limits - Prometheus needs memory for time-series data
  cpu_limit    = "2"
  memory_limit = "2GB"

  # Ensure networks and incus-metrics module are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.staging,
    incus_network.production,
    incus_network.management,
    module.incus_metrics
  ]
}

module "step_ca01" {
  source = "./modules/step-ca"

  instance_name = "step-ca01"
  profile_name  = "step-ca"

  # Uses ghcr.io image by default (ghcr:accuser/atlas/step-ca:latest)

  # Network configuration - use management network for internal services
  network_name = incus_network.management.name

  # CA configuration
  ca_name      = "Atlas Internal CA"
  ca_dns_names = "step-ca01.incus,step-ca01,localhost"

  # ACME endpoint configuration
  acme_port = "9000"

  # Certificate settings
  cert_duration = "24h"

  # Enable persistent storage for CA data
  enable_data_persistence = true
  data_volume_name        = "step-ca01-data"
  data_volume_size        = "1GB"

  # Resource limits - step-ca is lightweight
  cpu_limit    = "1"
  memory_limit = "512MB"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.staging,
    incus_network.production,
    incus_network.management
  ]
}

module "node_exporter01" {
  source = "./modules/node-exporter"

  instance_name = "node-exporter01"
  profile_name  = "node-exporter"

  # Network configuration - use management network for internal services
  network_name = incus_network.management.name

  # Node Exporter configuration
  node_exporter_port = "9100"

  # Resource limits - Node Exporter is very lightweight
  cpu_limit    = "1"
  memory_limit = "128MB"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.staging,
    incus_network.production,
    incus_network.management
  ]
}

module "alertmanager01" {
  source = "./modules/alertmanager"

  instance_name = "alertmanager01"
  profile_name  = "alertmanager"

  # Network configuration - use management network for internal services
  network_name = incus_network.management.name

  # Alertmanager configuration
  alertmanager_port = "9093"

  # Enable persistent storage for silences and notification state
  enable_data_persistence = true
  data_volume_name        = "alertmanager01-data"
  data_volume_size        = "1GB"

  # Resource limits - Alertmanager is lightweight
  cpu_limit    = "1"
  memory_limit = "256MB"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.staging,
    incus_network.production,
    incus_network.management
  ]
}

module "mosquitto01" {
  source = "./modules/mosquitto"

  instance_name = "mosquitto01"
  profile_name  = "mosquitto"

  # Network configuration - use production network for externally-accessible services
  network_name = incus_network.production.name

  # MQTT port configuration
  mqtt_port  = "1883"
  mqtts_port = "8883"

  # External access via Incus proxy devices
  # This exposes MQTT ports on the host for external clients
  enable_external_access = true
  external_mqtt_port     = "1883"
  external_mqtts_port    = "8883"

  # TLS is disabled by default - enable with step-ca fingerprint when ready
  # enable_tls         = true
  # stepca_url         = "https://step-ca01.incus:9000"
  # stepca_fingerprint = "your-fingerprint-here"

  # Enable persistent storage for retained messages and subscriptions
  enable_data_persistence = true
  data_volume_name        = "mosquitto01-data"
  data_volume_size        = "5GB"

  # Resource limits - Mosquitto is lightweight
  cpu_limit    = "1"
  memory_limit = "256MB"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.staging,
    incus_network.production,
    incus_network.management
  ]
}

module "cloudflared01" {
  source = "./modules/cloudflared"

  count = var.cloudflared_tunnel_token != "" ? 1 : 0

  instance_name = "cloudflared01"
  profile_name  = "cloudflared"

  # Network configuration - use management network to access internal services
  network_name = incus_network.management.name

  # Tunnel token from Cloudflare Zero Trust dashboard
  tunnel_token = var.cloudflared_tunnel_token

  # Resource limits - cloudflared is lightweight
  cpu_limit    = "1"
  memory_limit = "256MB"

  # Ensure networks are created before the container
  depends_on = [
    incus_network.development,
    incus_network.testing,
    incus_network.staging,
    incus_network.production,
    incus_network.management
  ]
}

module "incus_metrics" {
  source = "./modules/incus-metrics"

  count = var.enable_incus_metrics ? 1 : 0

  certificate_name        = "prometheus-metrics"
  certificate_description = "Metrics certificate for Prometheus to scrape Incus container metrics"
  incus_server_address    = var.incus_metrics_address
}

module "incus_loki" {
  source = "./modules/incus-loki"

  count = var.enable_incus_loki ? 1 : 0

  logging_name = "loki01"
  # Use IP-based endpoint because Incus daemon runs on host and cannot resolve .incus DNS
  loki_address = module.loki01.loki_endpoint_ip

  # Send lifecycle and logging events to Loki
  log_types = "lifecycle,logging"

  # Ensure Loki is running before configuring logging
  depends_on = [module.loki01]
}
