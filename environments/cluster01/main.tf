# =============================================================================
# Cluster Environment - Production Workloads
# =============================================================================
# This environment manages an IncusOS cluster.
# Cluster nodes are discovered dynamically via the Incus API.
#
# Services deployed here:
#   - Prometheus (local scraping, federated by iapetus)
#   - Promtail (ships logs to iapetus Loki)
#   - node-exporter × N (pinned to each cluster node)
#   - Alertmanager
#   - Mosquitto (MQTT broker)
#   - CoreDNS (local DNS)
# =============================================================================

# =============================================================================
# Cluster Node Discovery
# =============================================================================
# Query cluster membership dynamically from the Incus API
# This ensures the configuration always reflects the actual cluster state

data "external" "cluster_nodes" {
  program = ["bash", "-c", <<-EOF
    # Query cluster nodes and return as JSON with both names and IPs
    # External data source requires string values
    cluster_json=$(incus cluster list --format json 2>/dev/null)
    nodes=$(echo "$cluster_json" | jq -c '[.[].server_name]')
    # Extract IPs from URLs (https://192.168.71.5:8443 -> 192.168.71.5)
    ips=$(echo "$cluster_json" | jq -c '[.[].url | gsub("https://"; "") | gsub(":8443"; "")]')
    echo "{\"nodes_json\": $(echo "$nodes" | jq -Rs '.'), \"ips_json\": $(echo "$ips" | jq -Rs '.')}"
  EOF
  ]
}

locals {
  # Parse the cluster nodes from the external data source
  # The nodes_json is a JSON-encoded string containing a JSON array
  cluster_nodes = jsondecode(data.external.cluster_nodes.result.nodes_json)
  cluster_ips   = jsondecode(data.external.cluster_nodes.result.ips_json)

  # Create a map of node names to their IPs for easy lookup
  node_ip_map = zipmap(local.cluster_nodes, local.cluster_ips)
}

# =============================================================================
# Base Infrastructure
# =============================================================================

module "base" {
  source = "../../modules/base-infrastructure"

  storage_pool = "local"

  # Cluster configuration
  is_cluster = true
  # cluster_target_node not needed when using external management network

  # OVN configuration
  network_backend    = var.network_backend
  ovn_uplink_network = var.ovn_uplink_network
  ovn_integration    = var.ovn_integration

  # Production network configuration (physical mode - already exists on cluster)
  # When using OVN, this is ignored and OVN networks are created instead
  production_network_name   = var.production_network_name
  production_network_type   = var.production_network_type
  production_network_parent = var.production_network_parent

  production_network_ipv4     = var.production_network_ipv4
  production_network_nat      = var.production_network_nat
  production_network_ipv6     = var.production_network_ipv6
  production_network_ipv6_nat = var.production_network_ipv6_nat

  # Management network - use existing incusbr0 on cluster (bridge mode only)
  # When using OVN, OVN management network is created instead
  management_network_name     = var.management_network_name
  management_network_external = var.network_backend != "ovn"

  management_network_ipv4 = var.management_network_ipv4
  management_network_nat  = var.management_network_nat

  # No GitOps on cluster - managed from iapetus
  enable_gitops = false
}

# =============================================================================
# OVN Central (Container-based OVN Control Plane)
# =============================================================================
# Runs OVN northbound and southbound databases in a container on incusbr0.
# This provides the OVN control plane for IncusOS chassis nodes to connect to.
#
# After deployment, configure each IncusOS node as a chassis:
#   incus admin os service edit ovn --target=<node>
#   With config: {"enabled": true, "database": "tcp:<ovn-central-ip>:6642", "tunnel_address": "<node-ip>"}
#
# This module is only deployed when network_backend = "ovn"

module "ovn_central" {
  source = "../../modules/ovn-central"

  count = var.network_backend == "ovn" ? 1 : 0

  instance_name = "ovn-central01"
  profile_name  = "ovn-central"

  # Only use container-base profile (for boot.autorestart)
  # Network is handled directly in the ovn-central profile to avoid
  # chicken-and-egg dependency with OVN management network
  profiles = [
    module.base.container_base_profile.name,
  ]

  # Use incusbr0 directly - this is a non-OVN network that exists before OVN
  network_name = "incusbr0"

  # Pin to database-leader node for stability
  # This ensures the container and storage volume are on the same node
  target_node = "node02"

  # Physical network address for proxy device connections from other nodes
  host_address = local.node_ip_map["node02"]

  enable_data_persistence = true
  data_volume_name        = "ovn-central01-data"
  data_volume_size        = "1GB"

  cpu_limit    = "1"
  memory_limit = "512MB"
}

# =============================================================================
# OVN Configuration
# =============================================================================
# Configure Incus daemon to connect to OVN Central container.
# This sets network.ovn.northbound_connection to point to the ovn-central container.
#
# PREREQUISITE: After ovn-central is running, configure each IncusOS node as chassis:
#   incus admin os service edit ovn --target=<node>
#
# NOTE: When accessing the cluster via HAProxy load balancer, the incus_server
# resource may fail with ETag mismatch errors. Set skip_ovn_config=true and
# configure OVN manually instead:
#   incus config set network.ovn.northbound_connection=tcp:<ovn-central-host-ip>:6641
#
# This module is only applied when network_backend = "ovn" and skip_ovn_config = false

module "ovn_config" {
  source = "../../modules/ovn-config"

  # Deploy when OVN backend is enabled and not skipped
  # Skip when OVN is already configured (e.g., via CLI) or has ETag issues in clusters
  count = var.network_backend == "ovn" && !var.skip_ovn_config ? 1 : 0

  # Point to the ovn-central container's northbound database
  northbound_connection = module.ovn_central[0].northbound_connection

  depends_on = [module.ovn_central]
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
      %{for node in local.cluster_nodes~}
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

  for_each = toset(local.cluster_nodes)

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
  # With OVN, we use OVN load balancers instead
  enable_external_access = var.network_backend == "bridge" && !module.base.production_network_is_physical
  use_ovn_lb             = var.network_backend == "ovn"
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

  # External access via proxy devices (bridge mode only)
  # With OVN, we use OVN load balancers instead
  enable_external_access = var.network_backend == "bridge" && !module.base.production_network_is_physical
  use_ovn_lb             = var.network_backend == "ovn"
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

module "promtail01" {
  source = "../../modules/promtail"

  instance_name = "promtail01"
  profile_name  = "promtail"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  loki_push_url = var.loki_push_url

  extra_labels = {
    environment = "cluster"
  }

  cpu_limit    = local.services.promtail.cpu
  memory_limit = local.services.promtail.memory
}

# =============================================================================
# OVN Load Balancers (Optional - when using OVN backend)
# =============================================================================
# OVN load balancers replace proxy devices for external service access
# VIPs must be within the uplink network's ipv4.ovn.ranges

module "mosquitto_lb" {
  source = "../../modules/ovn-load-balancer"

  count = var.network_backend == "ovn" && var.mosquitto_lb_address != "" ? 1 : 0

  network_name   = module.base.production_network_name
  listen_address = var.mosquitto_lb_address
  description    = "OVN load balancer for Mosquitto MQTT broker"

  backends = [
    {
      name           = "mosquitto01"
      target_address = module.mosquitto01.ipv4_address
      target_port    = 1883
    }
  ]

  ports = [
    {
      description = "MQTT"
      protocol    = "tcp"
      listen_port = 1883
    },
    {
      description = "MQTTS"
      protocol    = "tcp"
      listen_port = 8883
    }
  ]
}

module "coredns_lb" {
  source = "../../modules/ovn-load-balancer"

  count = var.network_backend == "ovn" && var.coredns_lb_address != "" ? 1 : 0

  network_name   = module.base.production_network_name
  listen_address = var.coredns_lb_address
  description    = "OVN load balancer for CoreDNS"

  backends = [
    {
      name           = "coredns01"
      target_address = module.coredns01.ipv4_address
      target_port    = 53
    }
  ]

  ports = [
    {
      description = "DNS over UDP"
      protocol    = "udp"
      listen_port = 53
    },
    {
      description = "DNS over TCP"
      protocol    = "tcp"
      listen_port = 53
    }
  ]
}
