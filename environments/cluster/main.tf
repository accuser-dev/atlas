# =============================================================================
# Cluster Environment - Production Workloads
# =============================================================================
# This environment manages the 3-node IncusOS cluster:
#   - prometheus (node 1)
#   - epimetheus (node 2)
#   - menoetius (node 3)
#
# Services deployed here:
#   - Prometheus (local scraping, federated by iapetus)
#   - Promtail (ships logs to iapetus Loki)
#   - node-exporter × 3 (pinned to each cluster node)
#   - Alertmanager
#   - Mosquitto (MQTT broker)
#   - CoreDNS (local DNS)
# =============================================================================

# =============================================================================
# Base Infrastructure
# =============================================================================

module "base" {
  source = "../../modules/base-infrastructure"

  storage_pool = "local"

  # Network configuration
  production_network_name   = var.production_network_name
  production_network_type   = var.production_network_type
  production_network_parent = var.production_network_parent

  production_network_ipv4     = var.production_network_ipv4
  production_network_nat      = var.production_network_nat
  production_network_ipv6     = var.production_network_ipv6
  production_network_ipv6_nat = var.production_network_ipv6_nat

  management_network_ipv4     = var.management_network_ipv4
  management_network_nat      = var.management_network_nat
  management_network_ipv6     = var.management_network_ipv6
  management_network_ipv6_nat = var.management_network_ipv6_nat

  # No GitOps on cluster - managed from iapetus
  enable_gitops = false
}

# =============================================================================
# Monitoring Services
# =============================================================================

module "prometheus01" {
  source = "../../modules/prometheus"

  instance_name = "prometheus01"
  profile_name  = "prometheus"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  prometheus_port = "9090"

  # Local scraping configuration - federated by iapetus Prometheus
  prometheus_config = <<-EOT
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: 'production'
        environment: 'cluster'

    scrape_configs:
      # Prometheus self-monitoring
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
            labels:
              service: 'prometheus'
              instance: 'prometheus01'

      # Node exporters on each cluster node
      %{for node in var.cluster_nodes~}
      - job_name: 'node-${node}'
        static_configs:
          - targets: ['node-exporter-${node}.incus:9100']
            labels:
              service: 'node-exporter'
              node: '${node}'
      %{endfor~}

      # Alertmanager
      - job_name: 'alertmanager'
        static_configs:
          - targets: ['alertmanager01.incus:9093']
            labels:
              service: 'alertmanager'
              instance: 'alertmanager01'

      # Mosquitto (if metrics enabled)
      - job_name: 'mosquitto'
        static_configs:
          - targets: ['mosquitto01.incus:9001']
            labels:
              service: 'mosquitto'
              instance: 'mosquitto01'

      # CoreDNS metrics
      - job_name: 'coredns'
        static_configs:
          - targets: ['coredns01.incus:9153']
            labels:
              service: 'coredns'
              instance: 'coredns01'

      # Promtail metrics
      - job_name: 'promtail'
        static_configs:
          - targets: ['promtail01.incus:9080']
            labels:
              service: 'promtail'
              instance: 'promtail01'

      # Incus container metrics (mTLS)
      - job_name: 'incus'
        metrics_path: '/1.0/metrics'
        scheme: 'https'
        static_configs:
          - targets: ['${var.incus_metrics_address}']
            labels:
              service: 'incus'
              instance: 'incus-cluster'
        tls_config:
          cert_file: '/etc/prometheus/tls/metrics.crt'
          key_file: '/etc/prometheus/tls/metrics.key'
%{if var.incus_metrics_server_name != ""~}
          server_name: '${var.incus_metrics_server_name}'
%{else~}
          insecure_skip_verify: true
%{endif~}

    alerting:
      alertmanagers:
        - static_configs:
            - targets: ['alertmanager01.incus:9093']
  EOT

  # Alert rules
  alert_rules = fileexists("${path.module}/prometheus-alerts.yml") ? file("${path.module}/prometheus-alerts.yml") : ""

  # Incus metrics certificate
  incus_metrics_certificate = var.enable_incus_metrics ? module.incus_metrics[0].metrics_certificate_pem : ""
  incus_metrics_private_key = var.enable_incus_metrics ? module.incus_metrics[0].metrics_private_key_pem : ""

  enable_data_persistence = true
  data_volume_name        = "prometheus01-data"
  data_volume_size        = "100GB"

  cpu_limit    = local.services.prometheus.cpu
  memory_limit = local.services.prometheus.memory
}

module "alertmanager01" {
  source = "../../modules/alertmanager"

  instance_name = "alertmanager01"
  profile_name  = "alertmanager"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  alertmanager_port = "9093"

  enable_data_persistence = true
  data_volume_name        = "alertmanager01-data"
  data_volume_size        = "1GB"

  cpu_limit    = local.services.alertmanager.cpu
  memory_limit = local.services.alertmanager.memory
}

# =============================================================================
# Node Exporters - Pinned to Each Cluster Node
# =============================================================================

module "node_exporter" {
  source = "../../modules/node-exporter"

  for_each = toset(var.cluster_nodes)

  instance_name = "node-exporter-${each.key}"
  profile_name  = "node-exporter-${each.key}"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  node_exporter_port = "9100"

  # Pin to specific cluster node
  target_node = each.key

  cpu_limit    = local.services.node_exporter.cpu
  memory_limit = local.services.node_exporter.memory
}

# =============================================================================
# Application Services
# =============================================================================

module "mosquitto01" {
  source = "../../modules/mosquitto"

  instance_name = "mosquitto01"
  profile_name  = "mosquitto"

  profiles = [
    module.base.container_base_profile.name,
    module.base.production_network_profile.name,
  ]

  mqtt_port  = "1883"
  mqtts_port = "8883"

  # External access via proxy devices (bridge mode only)
  enable_external_access = !module.base.production_network_is_physical
  external_mqtt_port     = "1883"
  external_mqtts_port    = "8883"

  enable_data_persistence = true
  data_volume_name        = "mosquitto01-data"
  data_volume_size        = "5GB"

  cpu_limit    = local.services.mosquitto.cpu
  memory_limit = local.services.mosquitto.memory
}

module "coredns01" {
  source = "../../modules/coredns"

  instance_name = "coredns01"
  profile_name  = "coredns"

  profiles = [
    module.base.container_base_profile.name,
    module.base.production_network_profile.name,
  ]

  domain = var.dns_domain

  # Collect DNS records from service modules
  dns_records = []

  additional_records = var.dns_additional_records

  nameserver_ip = module.base.production_network_is_physical ? var.dns_nameserver_ip : split("/", var.production_network_ipv4)[0]

  incus_dns_server     = split("/", var.management_network_ipv4)[0]
  upstream_dns_servers = var.dns_upstream_servers

  enable_external_access = !module.base.production_network_is_physical
  external_dns_port      = "53"

  cpu_limit    = local.services.coredns.cpu
  memory_limit = local.services.coredns.memory
}

# =============================================================================
# Incus Metrics
# =============================================================================

module "incus_metrics" {
  source = "../../modules/incus-metrics"

  count = var.enable_incus_metrics ? 1 : 0

  certificate_name        = "prometheus-metrics-cluster"
  certificate_description = "Metrics certificate for Prometheus to scrape cluster Incus metrics"
  incus_server_address    = var.incus_metrics_address
}

# =============================================================================
# Log Shipping (Promtail)
# =============================================================================
# TODO: Create promtail module in Phase 3
# module "promtail01" {
#   source = "../../modules/promtail"
#
#   instance_name = "promtail01"
#   profile_name  = "promtail"
#
#   profiles = [
#     module.base.container_base_profile.name,
#     module.base.management_network_profile.name,
#   ]
#
#   loki_push_url = var.loki_push_url
#
#   cpu_limit    = local.services.promtail.cpu
#   memory_limit = local.services.promtail.memory
# }
