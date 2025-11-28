# =============================================================================
# Base Infrastructure
# =============================================================================
# Provides networks and base profiles for all containers

module "base" {
  source = "./modules/base-infrastructure"

  storage_pool = "local"

  # Network configuration - pass through from root variables
  development_network_ipv4     = var.development_network_ipv4
  development_network_nat      = var.development_network_nat
  development_network_ipv6     = var.development_network_ipv6
  development_network_ipv6_nat = var.development_network_ipv6_nat

  testing_network_ipv4     = var.testing_network_ipv4
  testing_network_nat      = var.testing_network_nat
  testing_network_ipv6     = var.testing_network_ipv6
  testing_network_ipv6_nat = var.testing_network_ipv6_nat

  staging_network_ipv4     = var.staging_network_ipv4
  staging_network_nat      = var.staging_network_nat
  staging_network_ipv6     = var.staging_network_ipv6
  staging_network_ipv6_nat = var.staging_network_ipv6_nat

  production_network_ipv4     = var.production_network_ipv4
  production_network_nat      = var.production_network_nat
  production_network_ipv6     = var.production_network_ipv6
  production_network_ipv6_nat = var.production_network_ipv6_nat

  management_network_ipv4     = var.management_network_ipv4
  management_network_nat      = var.management_network_nat
  management_network_ipv6     = var.management_network_ipv6
  management_network_ipv6_nat = var.management_network_ipv6_nat
}

# =============================================================================
# Services
# =============================================================================

module "caddy01" {
  source = "./modules/caddy"

  instance_name        = "caddy01"
  profile_name         = "caddy"
  cloudflare_api_token = var.cloudflare_api_token

  # Profile composition - base profile provides root disk
  # Caddy manages its own multi-network setup (production, management, external)
  profiles = [
    "default",
    module.base.docker_base_profile.name,
  ]

  # Service blocks from all modules
  service_blocks = [
    module.grafana01.caddy_config_block,
    # Add more service blocks here as you create more modules
  ]

  # Network configuration - reference managed networks
  # Caddy has special multi-network setup for reverse proxy functionality
  production_network = module.base.production_network.name
  management_network = module.base.management_network.name
  external_network   = "incusbr0"

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.caddy.cpu
  memory_limit = local.services.caddy.memory

  # Network dependencies are implicit through production_network and management_network references
}

module "grafana01" {
  source = "./modules/grafana"

  instance_name = "grafana01"
  profile_name  = "grafana"

  # Profile composition - base profiles provide root disk and network
  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.management_network_profile.name,
  ]

  # Domain configuration for reverse proxy
  domain           = "grafana.accuser.dev"
  allowed_ip_range = var.allowed_ip_range
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

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.grafana.cpu
  memory_limit = local.services.grafana.memory
}

module "loki01" {
  source = "./modules/loki"

  instance_name = "loki01"
  profile_name  = "loki"

  # Profile composition - base profiles provide root disk and network
  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.management_network_profile.name,
  ]

  # Loki configuration
  loki_port = "3100"

  # Enable persistent storage for log data
  enable_data_persistence = true
  data_volume_name        = "loki01-data"
  data_volume_size        = "50GB"

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.loki.cpu
  memory_limit = local.services.loki.memory
}

module "prometheus01" {
  source = "./modules/prometheus"

  instance_name = "prometheus01"
  profile_name  = "prometheus"

  # Profile composition - base profiles provide root disk and network
  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.management_network_profile.name,
  ]

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

      # NOTE: step-ca does not expose Prometheus metrics.
      # The /health endpoint returns JSON, not Prometheus format.
      # Health monitoring for step-ca should use blackbox exporter or external probes.

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
          # Client certificate for mTLS authentication to Incus API
          cert_file: '/etc/prometheus/tls/metrics.crt'
          key_file: '/etc/prometheus/tls/metrics.key'
%{if var.incus_metrics_server_name != ""~}
          # TLS server verification enabled - Incus has ACME certificate
          server_name: '${var.incus_metrics_server_name}'
%{else~}
          # SECURITY NOTE: Server certificate verification is disabled because Incus
          # uses a self-signed certificate. Set 'incus_metrics_server_name' to the
          # ACME domain (from 'incus config get acme.domain') to enable verification.
          #
          # Mitigating factors:
          # - Traffic is internal (management network only)
          # - mTLS client authentication is still enforced (Incus validates our cert)
          insecure_skip_verify: true
%{endif~}

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

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.prometheus.cpu
  memory_limit = local.services.prometheus.memory
}

module "step_ca01" {
  source = "./modules/step-ca"

  instance_name = "step-ca01"
  profile_name  = "step-ca"

  # Profile composition - base profiles provide root disk and network
  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.management_network_profile.name,
  ]

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

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.step_ca.cpu
  memory_limit = local.services.step_ca.memory
}

module "node_exporter01" {
  source = "./modules/node-exporter"

  instance_name = "node-exporter01"
  profile_name  = "node-exporter"

  # Profile composition - base profiles provide root disk and network
  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.management_network_profile.name,
  ]

  # Node Exporter configuration
  node_exporter_port = "9100"

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.node_exporter.cpu
  memory_limit = local.services.node_exporter.memory
}

module "alertmanager01" {
  source = "./modules/alertmanager"

  instance_name = "alertmanager01"
  profile_name  = "alertmanager"

  # Profile composition - base profiles provide root disk and network
  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.management_network_profile.name,
  ]

  # Alertmanager configuration
  alertmanager_port = "9093"

  # Enable persistent storage for silences and notification state
  enable_data_persistence = true
  data_volume_name        = "alertmanager01-data"
  data_volume_size        = "1GB"

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.alertmanager.cpu
  memory_limit = local.services.alertmanager.memory
}

module "mosquitto01" {
  source = "./modules/mosquitto"

  instance_name = "mosquitto01"
  profile_name  = "mosquitto"

  # Profile composition - base profiles provide root disk and network
  # Note: mosquitto uses production network for external access
  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.production_network_profile.name,
  ]

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

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.mosquitto.cpu
  memory_limit = local.services.mosquitto.memory
}

module "cloudflared01" {
  source = "./modules/cloudflared"

  count = var.cloudflared_tunnel_token != "" ? 1 : 0

  instance_name = "cloudflared01"
  profile_name  = "cloudflared"

  # Profile composition - base profiles provide root disk and network
  profiles = [
    "default",
    module.base.docker_base_profile.name,
    module.base.management_network_profile.name,
  ]

  # Tunnel token from Cloudflare Zero Trust dashboard
  tunnel_token = var.cloudflared_tunnel_token

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.cloudflared.cpu
  memory_limit = local.services.cloudflared.memory
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

  # Loki dependency is implicit through loki_address reference
}
