# =============================================================================
# Cluster Environment - Production Workloads
# =============================================================================
# This environment manages an IncusOS cluster.
# Cluster nodes are discovered dynamically via the Incus API.
#
# Services deployed here:
#   - Prometheus (local scraping, federated by iapetus)
#   - Alloy (ships logs to iapetus Loki)
#   - Alertmanager
#   - Mosquitto (MQTT broker)
#   - CoreDNS (local DNS)
#
# Note: Host metrics are scraped directly from IncusOS nodes via /1.0/metrics
# endpoint (no separate node-exporter containers needed)
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
    # Use cluster01: remote explicitly since this script runs outside provider context
    cluster_json=$(incus cluster list cluster01: --format json 2>/dev/null)
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

  # Link management network to Incus DNS zone for automatic container DNS
  # Note: Only works when OVN is enabled (creates ovn-management network)
  # For bridge mode with external incusbr0, configure dns.zone.forward manually
  dns_zone_forward = var.enable_incus_dns_zone && var.network_backend == "ovn" ? var.incus_dns_zone_name : ""
}

# =============================================================================
# Incus Network Zone (Optional - for automatic container DNS)
# =============================================================================
# Creates a network zone for automatic DNS registration of containers.
# Containers become accessible as <name>.<zone> (e.g., prometheus01.cluster01.accuser.dev)

module "network_zone" {
  source = "../../modules/incus-network-zone"

  count = var.enable_incus_dns_zone ? 1 : 0

  zone_name   = var.incus_dns_zone_name
  description = "Incus container DNS zone for cluster01"

  # DNS server configuration for zone transfers
  configure_dns_server  = true
  dns_listen_address    = var.incus_dns_listen_address
  dns_reachable_address = var.incus_dns_reachable_address

  # Allow CoreDNS to request zone transfers
  transfer_peers = var.incus_dns_transfer_peer_ip != "" ? {
    coredns = var.incus_dns_transfer_peer_ip
  } : {}
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

  profiles = local.management_profiles

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

      # Alloy metrics
      - job_name: 'alloy'
        static_configs:
          - targets: ['alloy01.incus:12345']
            labels:
              service: 'alloy'
              instance: 'alloy01'

      # Incus metrics from each IncusOS cluster node (mTLS)
      # Each node exposes its own metrics including node_exporter-style host metrics
%{for i, node in local.cluster_nodes}
      - job_name: 'incus-${node}'
        metrics_path: '/1.0/metrics'
        scheme: 'https'
        static_configs:
          - targets: ['${local.cluster_ips[i]}:8443']
            labels:
              service: 'incus'
              instance: '${node}'
              node: '${node}'
        tls_config:
          cert_file: '/etc/prometheus/tls/metrics.crt'
          key_file: '/etc/prometheus/tls/metrics.key'
%{if var.incus_metrics_server_name != ""~}
          server_name: '${var.incus_metrics_server_name}'
%{else~}
          insecure_skip_verify: true
%{endif~}
%{endfor}

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

  # Pin to specific cluster node for storage volume co-location
  target_node = "node01"

  cpu_limit    = local.services.prometheus.cpu
  memory_limit = local.services.prometheus.memory
}

module "alertmanager01" {
  source = "../../modules/alertmanager"

  instance_name = "alertmanager01"
  profile_name  = "alertmanager"

  profiles = local.management_profiles

  alertmanager_port = "9093"

  enable_data_persistence = true
  data_volume_name        = "alertmanager01-data"
  data_volume_size        = "1GB"

  # Pin to specific cluster node for storage volume co-location
  target_node = "node01"

  cpu_limit    = local.services.alertmanager.cpu
  memory_limit = local.services.alertmanager.memory
}

# =============================================================================
# Application Services
# =============================================================================

module "mosquitto01" {
  source = "../../modules/mosquitto"

  instance_name = "mosquitto01"
  profile_name  = "mosquitto"

  profiles = local.production_profiles

  mqtt_port  = "1883"
  mqtts_port = "8883"

  # External access via proxy devices (bridge mode only)
  # With OVN, we use OVN load balancers instead
  enable_external_access = local.bridge_external_access
  use_ovn_lb             = local.use_ovn_lb
  external_mqtt_port     = "1883"
  external_mqtts_port    = "8883"

  enable_data_persistence = true
  data_volume_name        = "mosquitto01-data"
  data_volume_size        = "5GB"

  # Pin to specific cluster node for storage volume co-location
  target_node = "node01"

  cpu_limit    = local.services.mosquitto.cpu
  memory_limit = local.services.mosquitto.memory
}

module "coredns01" {
  source = "../../modules/coredns"

  instance_name = "coredns01"
  profile_name  = "coredns"

  profiles = local.production_profiles

  domain = var.dns_domain

  # Collect DNS records from service modules
  dns_records = []

  additional_records = var.dns_additional_records

  nameserver_ip = module.base.production_network_is_physical ? var.dns_nameserver_ip : split("/", var.production_network_ipv4)[0]

  incus_dns_server     = split("/", var.management_network_ipv4)[0]
  upstream_dns_servers = var.dns_upstream_servers

  # Secondary zones - pull local Incus network zone via AXFR
  secondary_zones = var.enable_incus_dns_zone ? [
    {
      zone   = var.incus_dns_zone_name
      master = module.network_zone[0].dns_reachable_address
    }
  ] : []

  # Forward iapetus.accuser.dev queries to iapetus CoreDNS for cross-environment DNS
  forward_zones = var.iapetus_coredns_address != "" ? [{
    zone    = var.iapetus_dns_zone_name
    servers = [var.iapetus_coredns_address]
  }] : []

  # External access via proxy devices (bridge mode only)
  # With OVN, we use OVN load balancers instead
  enable_external_access = local.bridge_external_access
  use_ovn_lb             = local.use_ovn_lb
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
# Log Shipping (Alloy)
# =============================================================================
# Grafana Alloy replaces Promtail (EOL) for log shipping to Loki

module "alloy01" {
  source = "../../modules/alloy"

  instance_name = "alloy01"
  profile_name  = "alloy"

  profiles = local.management_profiles

  loki_push_url = var.loki_push_url

  extra_labels = {
    environment = "cluster"
  }

  # Enable syslog receiver for IncusOS host logs
  enable_syslog_receiver = true
  syslog_port            = "1514"

  cpu_limit    = local.services.alloy.cpu
  memory_limit = local.services.alloy.memory
}

# =============================================================================
# OVN Load Balancers (Optional - when using OVN backend)
# =============================================================================
# OVN load balancers replace proxy devices for external service access
# VIPs must be within the uplink network's ipv4.ovn.ranges
#
# Configuration is centralized in locals.tf (local.ovn_load_balancers)

module "ovn_lb" {
  source = "../../modules/ovn-load-balancer"

  for_each = local.use_ovn_lb ? {
    for k, v in local.ovn_load_balancers : k => v if v.enabled
  } : {}

  network_name   = each.value.network == "production" ? module.base.production_network_name : module.base.management_network_name
  listen_address = each.value.listen_address
  description    = each.value.description
  backends       = each.value.backends
  ports          = each.value.ports
  health_check   = try(each.value.health_check, {})
}

# =============================================================================
# Ceph Distributed Storage
# =============================================================================
# Provides distributed block storage and S3-compatible object storage.
# Requires a storage network configured on IncusOS hosts.
#
# Deployment order: MON (bootstrap) → MON (join) → MGR → OSD → RGW
# Post-deployment: Copy keys from bootstrap MON to other containers

module "ceph" {
  source = "../../modules/ceph"

  count = var.enable_ceph ? 1 : 0

  cluster_name = "ceph"
  cluster_fsid = var.ceph_cluster_fsid

  # Include management network profile for internet access during package installation
  profiles     = [module.base.container_base_profile.name, module.base.management_network_profile.name]
  storage_pool = "local"

  # Network configuration
  storage_network_name = var.ceph_storage_network_name
  public_network       = var.ceph_public_network
  cluster_network      = var.ceph_cluster_network

  # MON configuration (3 monitors for quorum)
  # First node in the cluster is the bootstrap node
  mons = {
    for i, node in local.cluster_nodes : node => {
      target_node  = node
      static_ip    = lookup(var.ceph_mon_ips, node, null)
      is_bootstrap = i == 0
    }
  }

  mon_cpu_limit    = local.services.ceph_mon.cpu
  mon_memory_limit = local.services.ceph_mon.memory

  # MGR configuration (runs on first node)
  mgrs = {
    (local.cluster_nodes[0]) = {
      target_node = local.cluster_nodes[0]
      static_ip   = lookup(var.ceph_mgr_ips, local.cluster_nodes[0], null)
    }
  }

  mgr_cpu_limit         = local.services.ceph_mgr.cpu
  mgr_memory_limit      = local.services.ceph_mgr.memory
  enable_mgr_prometheus = true

  # OSD configuration (one per node, using the discovered HDD)
  osds = {
    for node in local.cluster_nodes : node => {
      target_node      = node
      osd_block_device = var.ceph_osd_devices[node]
      static_ip        = lookup(var.ceph_osd_ips, node, null)
    } if contains(keys(var.ceph_osd_devices), node)
  }

  osd_cpu_limit    = local.services.ceph_osd.cpu
  osd_memory_limit = local.services.ceph_osd.memory

  # RGW configuration (S3 API, runs on first node)
  rgws = {
    (local.cluster_nodes[0]) = {
      target_node = local.cluster_nodes[0]
      static_ip   = lookup(var.ceph_rgw_ips, local.cluster_nodes[0], null)
    }
  }

  rgw_cpu_limit    = local.services.ceph_rgw.cpu
  rgw_memory_limit = local.services.ceph_rgw.memory
}

# =============================================================================
# Ceph RGW Load Balancer (OVN)
# =============================================================================
# Provides LAN-routable VIP for S3 API access from external hosts (e.g., iapetus)

module "ceph_rgw_lb" {
  source = "../../modules/ovn-load-balancer"

  count = var.network_backend == "ovn" && var.enable_ceph && var.ceph_rgw_lb_address != "" ? 1 : 0

  # Use the Ceph storage network since RGW is on that network
  network_name   = var.ceph_storage_network_name
  listen_address = var.ceph_rgw_lb_address
  description    = "OVN load balancer for Ceph RGW S3 API"

  backends = [
    for k, v in module.ceph[0].rgw_instances : {
      name           = k
      description    = "Ceph RGW on ${k}"
      target_address = v.ipv4_address
      target_port    = 7480
    }
  ]

  ports = [
    {
      description = "S3 API HTTP"
      protocol    = "tcp"
      listen_port = 7480
    }
  ]

  depends_on = [module.ceph]
}
