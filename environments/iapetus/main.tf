# =============================================================================
# Resource Summary
# =============================================================================
# Total CPU:     14 cores (soft limits)
# Total Memory:  7.5GB (hard limits)
# Total Storage: 167GB (default volumes)
# Networks:      2 internal + 1 external bridge (3 with GitOps enabled)
#
# See CLAUDE.md "Resource Requirements" section for detailed breakdown.
# =============================================================================

# =============================================================================
# Base Infrastructure
# =============================================================================
# Provides networks and base profiles for all containers

module "base" {
  source = "../../modules/base-infrastructure"

  storage_pool = "local"

  # OVN configuration
  network_backend         = var.network_backend
  ovn_uplink_network      = var.ovn_uplink_network
  ovn_integration         = var.ovn_integration
  ovn_production_external = var.ovn_production_external

  # Network configuration - simplified to production + management
  # Production network supports physical mode for IncusOS direct LAN attachment
  production_network_name   = var.production_network_name
  production_network_type   = var.production_network_type
  production_network_parent = var.production_network_parent

  # IPv4/IPv6 config only used when type is 'bridge' or 'ovn'
  production_network_ipv4     = var.production_network_ipv4
  production_network_nat      = var.production_network_nat
  production_network_ipv6     = var.production_network_ipv6
  production_network_ipv6_nat = var.production_network_ipv6_nat

  management_network_ipv4     = var.management_network_ipv4
  management_network_nat      = var.management_network_nat
  management_network_ipv6     = var.management_network_ipv6
  management_network_ipv6_nat = var.management_network_ipv6_nat

  # GitOps infrastructure (conditional)
  enable_gitops           = var.enable_gitops
  gitops_network_ipv4     = var.gitops_network_ipv4
  gitops_network_nat      = var.gitops_network_nat
  gitops_network_ipv6     = var.gitops_network_ipv6
  gitops_network_ipv6_nat = var.gitops_network_ipv6_nat

  # Link management network to Incus DNS zone for automatic container DNS
  dns_zone_forward = var.enable_incus_dns_zone ? var.incus_dns_zone_name : ""
}

# =============================================================================
# Incus Network Zone (Optional - for automatic container DNS)
# =============================================================================
# Creates a network zone for automatic DNS registration of containers.
# Containers become accessible as <name>.<zone> (e.g., grafana01.incus.accuser.dev)

module "network_zone" {
  source = "../../modules/incus-network-zone"

  count = var.enable_incus_dns_zone ? 1 : 0

  zone_name   = var.incus_dns_zone_name
  description = "Incus container DNS zone for Atlas infrastructure"

  # DNS server configuration for zone transfers
  configure_dns_server  = true
  dns_listen_address    = var.incus_dns_listen_address
  dns_reachable_address = var.incus_dns_reachable_address

  # Allow CoreDNS to request zone transfers
  # The peer IP must match the source IP the host sees (OVN NAT IP for production network)
  transfer_peers = var.incus_dns_transfer_peer_ip != "" ? {
    coredns = var.incus_dns_transfer_peer_ip
  } : {}
}

# =============================================================================
# Services
# =============================================================================

module "grafana01" {
  source = "../../modules/grafana"

  instance_name = "grafana01"
  profile_name  = "grafana"

  # Profile composition - container-base provides boot.autorestart, service profile provides root disk
  profiles = local.management_profiles

  # Domain configuration
  domain       = "grafana.accuser.dev"
  grafana_port = "3000"

  # Grafana admin credentials
  admin_user     = "admin"
  admin_password = var.grafana_admin_password

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
  source = "../../modules/loki"

  instance_name = "loki01"
  profile_name  = "loki"

  # Profile composition - container-base provides boot.autorestart, service profile provides root disk
  profiles = local.management_profiles

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
  source = "../../modules/prometheus"

  instance_name = "prometheus01"
  profile_name  = "prometheus"

  # Profile composition - container-base provides boot.autorestart, service profile provides root disk
  profiles = local.management_profiles

  # Prometheus configuration
  prometheus_port = "9090"

  # Prometheus configuration loaded from template file for better maintainability
  prometheus_config = templatefile("${path.module}/templates/prometheus.yml.tftpl", {
    enable_oidc                = var.enable_oidc
    incus_metrics_address      = var.incus_metrics_address
    incus_metrics_server_name  = var.incus_metrics_server_name
    cluster01_prometheus_url   = var.cluster01_prometheus_url
    cluster01_alertmanager_url = var.cluster01_alertmanager_url
  })

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
  source = "../../modules/step-ca"

  instance_name = "step-ca01"
  profile_name  = "step-ca"

  # Profile composition - container-base provides boot.autorestart, service profile provides root disk
  profiles = local.management_profiles

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

module "coredns01" {
  source = "../../modules/coredns"

  instance_name = "coredns01"
  profile_name  = "coredns"

  # Profile composition - container-base provides boot.autorestart, service profile provides root disk
  # Note: coredns uses production network for LAN client access
  profiles = local.production_profiles

  # Static IP configuration for DNS server (required for clients to find it)
  # In physical/bridge mode: dns_nameserver_ip and gateway must be set in tfvars
  # In OVN mode: container gets dynamic IP from OVN network, LB VIP provides LAN access
  ipv4_address = var.network_backend == "ovn" ? "" : var.dns_nameserver_ip
  ipv4_gateway = var.network_backend == "ovn" ? "" : var.dns_gateway_ip

  # Zone configuration - split-horizon for accuser.dev
  domain = var.dns_domain

  # Collect DNS records from all service modules that output them
  # Note: For services with OVN LB VIPs, use additional_records instead to point
  # to the LAN-routable VIP address rather than the internal container IP
  dns_records = []

  # Additional static DNS records (hosts, cluster nodes, manually configured services)
  additional_records = var.dns_additional_records

  # Nameserver IP - the LAN-routable address where clients reach the DNS server
  # In OVN mode: use the OVN load balancer VIP
  # In physical/bridge mode: use the static IP or production network gateway
  nameserver_ip = var.network_backend == "ovn" ? var.coredns_lb_address : (var.dns_nameserver_ip != "" ? var.dns_nameserver_ip : split("/", var.production_network_ipv4)[0])

  # Forwarding configuration
  incus_dns_server     = split("/", var.management_network_ipv4)[0] # Management network gateway
  upstream_dns_servers = var.dns_upstream_servers

  # Secondary zones - pull Incus network zone via AXFR
  secondary_zones = var.enable_incus_dns_zone ? [
    {
      zone   = var.incus_dns_zone_name
      master = module.network_zone[0].dns_reachable_address
    }
  ] : []

  # Forward cluster01.accuser.dev queries to cluster01 CoreDNS for cross-environment DNS
  forward_zones = var.cluster01_coredns_address != "" ? [{
    zone    = var.cluster01_dns_zone_name
    servers = [var.cluster01_coredns_address]
  }] : []

  # External access via Incus proxy devices (bridge mode only)
  # In physical mode, containers get LAN IPs directly - no proxy needed
  # With OVN, we use OVN load balancers instead
  enable_external_access = local.bridge_external_access
  use_ovn_lb             = local.use_ovn_lb
  external_dns_port      = "53"

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.coredns.cpu
  memory_limit = local.services.coredns.memory
}

module "cloudflared01" {
  source = "../../modules/cloudflared"

  count = var.cloudflared_tunnel_token != "" ? 1 : 0

  instance_name = "cloudflared01"
  profile_name  = "cloudflared"

  # Profile composition - container-base provides boot.autorestart, service profile provides root disk
  profiles = local.management_profiles

  # Tunnel token from Cloudflare Zero Trust dashboard
  tunnel_token = var.cloudflared_tunnel_token

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.cloudflared.cpu
  memory_limit = local.services.cloudflared.memory
}

module "incus_metrics" {
  source = "../../modules/incus-metrics"

  count = var.enable_incus_metrics ? 1 : 0

  certificate_name        = "prometheus-metrics"
  certificate_description = "Metrics certificate for Prometheus to scrape Incus container metrics"
  incus_server_address    = var.incus_metrics_address
}

module "incus_loki" {
  source = "../../modules/incus-loki"

  count = var.enable_incus_loki ? 1 : 0

  logging_name = "loki01"
  # Use IP-based endpoint because Incus daemon runs on host and cannot resolve .incus DNS
  loki_address = module.loki01.loki_endpoint_ip

  # Send lifecycle and logging events to Loki
  log_types = "lifecycle,logging"

  # Loki dependency is implicit through loki_address reference
}

# =============================================================================
# GitOps Automation
# =============================================================================

module "atlantis01" {
  source = "../../modules/atlantis"

  count = var.enable_gitops ? 1 : 0

  instance_name = "atlantis01"
  profile_name  = "atlantis"

  # Profile composition - container-base provides boot.autorestart, service profile provides root disk
  profiles = local.gitops_profiles

  # Domain configuration
  domain        = var.atlantis_domain
  atlantis_port = tostring(local.services.atlantis.port)

  # GitHub configuration (from terraform.tfvars)
  github_user           = var.atlantis_github_user
  github_token          = var.atlantis_github_token
  github_webhook_secret = var.atlantis_github_webhook_secret
  repo_allowlist        = var.atlantis_repo_allowlist
  atlantis_url          = "https://${var.atlantis_domain}"

  # Enable persistent storage for plans cache and locks
  enable_data_persistence = true
  data_volume_name        = "atlantis01-data"
  data_volume_size        = "10GB"

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.atlantis.cpu
  memory_limit = local.services.atlantis.memory
}

# =============================================================================
# OIDC / Authorization
# =============================================================================
# Dex provides federated OIDC authentication (via GitHub)
# OpenFGA provides fine-grained authorization for Incus

module "dex01" {
  source = "../../modules/dex"

  count = var.enable_oidc ? 1 : 0

  instance_name = "dex01"
  profile_name  = "dex"

  # Profile composition - container-base provides boot.autorestart, service profile provides root disk
  profiles = local.management_profiles

  # Dex OIDC configuration
  issuer_url = var.dex_issuer_url

  # GitHub connector for authentication
  github_client_id     = var.dex_github_client_id
  github_client_secret = var.dex_github_client_secret
  github_allowed_orgs  = var.dex_github_allowed_orgs

  # Static clients - Incus will use this client
  # Incus is a public client (CLI-based), so no secret is required
  static_clients = [
    {
      id     = "incus"
      name   = "Incus"
      public = true # Public client - no secret required for CLI/device flow
      redirect_uris = [
        "urn:ietf:wg:oauth:2.0:oob",                                # Device authorization grant (CLI)
        "/device/callback",                                         # Dex internal device flow callback
        "https://iapetus.accuser.dev:8443/oidc/callback",           # Incus OIDC callback (iapetus)
        "https://operations-center.accuser.dev:8443/oidc/callback", # Incus OIDC callback (operations-center)
        "https://atlas.accuser.dev:8443/oidc/callback",             # Incus OIDC callback (menotius)
        "https://cluster01.accuser.dev:8443/oidc/callback",         # Incus OIDC callback (cluster01)
      ]
    }
  ]

  # Enable persistent storage for SQLite database
  enable_data_persistence = true
  data_volume_name        = "dex01-data"
  data_volume_size        = "1GB"

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.dex.cpu
  memory_limit = local.services.dex.memory
}

module "openfga01" {
  source = "../../modules/openfga"

  count = var.enable_oidc ? 1 : 0

  instance_name = "openfga01"
  profile_name  = "openfga"

  # Profile composition - container-base provides boot.autorestart, service profile provides root disk
  profiles = local.management_profiles

  # OpenFGA authentication - Incus uses this key to communicate with OpenFGA
  preshared_keys = [var.openfga_preshared_key]

  # Disable playground in production (can be enabled for debugging)
  playground_port = ""

  # Enable persistent storage for SQLite database
  enable_data_persistence = true
  data_volume_name        = "openfga01-data"
  data_volume_size        = "1GB"

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.openfga.cpu
  memory_limit = local.services.openfga.memory
}

# =============================================================================
# HAProxy Load Balancer (Optional)
# =============================================================================
# Provides load balancing for Incus cluster nodes

module "haproxy01" {
  source = "../../modules/haproxy"

  count = var.enable_haproxy ? 1 : 0

  instance_name = "haproxy01"
  profile_name  = "haproxy"

  # Profile composition - container-base provides boot.autorestart, service profile provides root disk
  profiles = local.production_profiles

  # Stats interface configuration
  stats_port     = 8404
  stats_user     = "admin"
  stats_password = var.haproxy_stats_password

  # Incus cluster load balancing configuration
  frontends = [
    {
      name            = "incus_https"
      bind_port       = 8443
      mode            = "tcp"
      default_backend = "incus_cluster"
      options         = ["option tcplog"]
    }
  ]

  backends = [
    {
      name    = "incus_cluster"
      mode    = "tcp"
      balance = "source"
      options = [
        "hash-type consistent",
        "option tcp-check",
        "tcp-check connect ssl"
      ]
      servers = [
        for idx, ip in var.incus_cluster_nodes : {
          name    = "node${idx + 1}"
          address = ip
          port    = 8443
          options = "check verify none"
        }
      ]
    }
  ]

  # Resource limits (from centralized service config)
  cpu_limit    = local.services.haproxy.cpu
  memory_limit = local.services.haproxy.memory
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
}
