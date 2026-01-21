variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cloudflare_api_token) >= 40
    error_message = "Cloudflare API token appears invalid (must be at least 40 characters)"
  }
}

# Grafana Configuration
variable "grafana_admin_password" {
  description = "Grafana admin password (should be strong and unique)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 12
    error_message = "Grafana admin password must be at least 12 characters long for security"
  }
}

# =============================================================================
# Network Configuration
# =============================================================================
# Simplified network architecture:
#   - production (10.10.0.0/24): Public-facing services
#   - management (10.20.0.0/24): Internal monitoring services
#   - gitops (10.30.0.0/24): GitOps automation (optional)

# Production Network Configuration
variable "production_network_name" {
  description = "Name of the production network. For IncusOS physical mode, set this to match the physical interface name (e.g., 'eno1') to avoid creating a ghost network."
  type        = string
  default     = "production"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.production_network_name)) && length(var.production_network_name) <= 15
    error_message = "Network name must start with a letter, contain only alphanumeric characters and hyphens, and be at most 15 characters."
  }
}

variable "production_network_type" {
  description = "Network type: 'bridge' (default, NAT) or 'physical' (direct LAN attachment for IncusOS)"
  type        = string
  default     = "bridge"

  validation {
    condition     = contains(["bridge", "physical"], var.production_network_type)
    error_message = "production_network_type must be 'bridge' or 'physical'."
  }
}

variable "production_network_parent" {
  description = "Physical interface name when production_network_type is 'physical' (e.g., 'enp5s0', 'eth1'). Required when type is 'physical'. For IncusOS, ensure the interface has 'role instances' enabled."
  type        = string
  default     = ""
}

variable "production_network_ipv4" {
  description = "IPv4 address for production network (public-facing services). Only used when type is 'bridge'."
  type        = string
  default     = "10.10.0.1/24"

  validation {
    condition     = can(cidrhost(var.production_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.10.0.1/24)"
  }
}

variable "production_network_nat" {
  description = "Enable NAT for production network IPv4"
  type        = bool
  default     = true
}

variable "production_network_ipv6" {
  description = "IPv6 address for production network (e.g., fd00:10:10::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.production_network_ipv6 == "" || can(cidrhost(var.production_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:10::1/64)"
  }
}

variable "production_network_ipv6_nat" {
  description = "Enable NAT for production network IPv6"
  type        = bool
  default     = true
}

# Management Network Configuration
variable "management_network_ipv4" {
  description = "IPv4 address for management network (monitoring, internal services)"
  type        = string
  default     = "10.20.0.1/24"

  validation {
    condition     = can(cidrhost(var.management_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.20.0.1/24)"
  }
}

variable "management_network_nat" {
  description = "Enable NAT for management network IPv4"
  type        = bool
  default     = true
}

variable "management_network_ipv6" {
  description = "IPv6 address for management network (e.g., fd00:10:20::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.management_network_ipv6 == "" || can(cidrhost(var.management_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:20::1/64)"
  }
}

variable "management_network_ipv6_nat" {
  description = "Enable NAT for management network IPv6"
  type        = bool
  default     = true
}

# GitOps Network Configuration
variable "gitops_network_ipv4" {
  description = "IPv4 address for GitOps network (Atlantis, CI/CD automation)"
  type        = string
  default     = "10.30.0.1/24"

  validation {
    condition     = can(cidrhost(var.gitops_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.30.0.1/24)"
  }
}

variable "gitops_network_nat" {
  description = "Enable NAT for GitOps network IPv4"
  type        = bool
  default     = true
}

variable "gitops_network_ipv6" {
  description = "IPv6 address for GitOps network (e.g., fd00:10:30::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.gitops_network_ipv6 == "" || can(cidrhost(var.gitops_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:30::1/64)"
  }
}

variable "gitops_network_ipv6_nat" {
  description = "Enable NAT for GitOps network IPv6"
  type        = bool
  default     = true
}

# =============================================================================
# Service Configuration
# =============================================================================

# Cloudflared Configuration
variable "cloudflared_tunnel_token" {
  description = "Cloudflare Tunnel token from Zero Trust dashboard"
  type        = string
  sensitive   = true
  default     = ""
}

# Incus Metrics Configuration
variable "incus_metrics_address" {
  description = "Address of the Incus server for metrics scraping (e.g., '10.20.0.1:8443'). The management network gateway is typically used."
  type        = string
  default     = "10.20.0.1:8443"
}

variable "enable_incus_metrics" {
  description = "Enable scraping of Incus container metrics via the Incus API"
  type        = bool
  default     = true
}

variable "incus_metrics_server_name" {
  description = "Server name (SNI) for TLS verification of Incus metrics endpoint. Set to the ACME domain (e.g., 'incus.example.com') if Incus has ACME configured. Leave empty to skip TLS server verification (for self-signed certificates)."
  type        = string
  default     = ""
}

variable "enable_incus_loki" {
  description = "Enable native Incus logging to Loki (sends lifecycle and logging events)"
  type        = bool
  default     = true
}

# =============================================================================
# GitOps Configuration
# =============================================================================

variable "enable_gitops" {
  description = "Enable GitOps infrastructure (gitops network, caddy-gitops, and Atlantis)"
  type        = bool
  default     = false
}

variable "atlantis_domain" {
  description = "Domain for Atlantis webhook endpoint (e.g., 'atlantis.example.com')"
  type        = string
  default     = ""
}

variable "atlantis_github_user" {
  description = "GitHub username for Atlantis (required if enable_gitops is true)"
  type        = string
  default     = ""
}

variable "atlantis_github_token" {
  description = "GitHub personal access token for Atlantis (required if enable_gitops is true)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "atlantis_github_webhook_secret" {
  description = "Webhook secret for GitHub webhooks (required if enable_gitops is true)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "atlantis_repo_allowlist" {
  description = "List of repositories Atlantis is allowed to manage"
  type        = list(string)
  default     = ["github.com/accuser-dev/atlas"]
}

# =============================================================================
# DNS Configuration
# =============================================================================

variable "dns_domain" {
  description = "Primary domain for the internal DNS zone (e.g., 'accuser.dev'). CoreDNS will be authoritative for this zone."
  type        = string
  default     = "accuser.dev"
}

variable "dns_upstream_servers" {
  description = "List of upstream DNS servers for forwarding external queries"
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1"]
}

variable "dns_nameserver_ip" {
  description = "Static IP address for CoreDNS container. Required when production network is physical mode. In bridge mode, the production network gateway is used."
  type        = string
  default     = ""
}

variable "dns_gateway_ip" {
  description = "Gateway IP for CoreDNS static IP configuration. Required when dns_nameserver_ip is set."
  type        = string
  default     = ""
}

variable "dns_additional_records" {
  description = "Additional static DNS records not managed by service modules"
  type = list(object({
    name  = string
    type  = string
    value = string
    ttl   = optional(number, 300)
  }))
  default = []
}

# =============================================================================
# Incus Network Zone Configuration
# =============================================================================

variable "enable_incus_dns_zone" {
  description = "Enable Incus network zone for automatic container DNS registration. When enabled, containers are automatically registered as <name>.<zone>."
  type        = bool
  default     = false
}

variable "incus_dns_zone_name" {
  description = "DNS zone name for Incus containers (e.g., 'iapetus.incus'). Containers will be registered as <name>.<zone>."
  type        = string
  default     = "iapetus.incus"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.incus_dns_zone_name))
    error_message = "Zone name must be a valid DNS domain (lowercase, alphanumeric with dots and hyphens)"
  }
}

variable "incus_dns_listen_address" {
  description = "Address for Incus DNS server to listen on. Use ':5353' to bind all interfaces, or a specific host IP. Must be an IP the host actually has (not an OVN virtual gateway)."
  type        = string
  default     = ":5353"
}

variable "incus_dns_reachable_address" {
  description = "Address where CoreDNS can reach the Incus DNS server for zone transfers. For OVN environments, use the host's LAN IP (e.g., '192.168.68.84:5353'). Required when dns_listen_address binds to all interfaces."
  type        = string
  default     = ""
}

variable "incus_dns_transfer_peer_ip" {
  description = "Source IP that the Incus host sees for CoreDNS zone transfer requests. For OVN, this is the production network's NAT IP (volatile.network.ipv4.address). Required for zone transfers to work."
  type        = string
  default     = ""
}

# =============================================================================
# OIDC/Authorization Configuration
# =============================================================================

variable "enable_oidc" {
  description = "Enable OIDC authentication infrastructure (Dex and OpenFGA)"
  type        = bool
  default     = false
}

variable "dex_issuer_url" {
  description = "The public issuer URL for Dex (e.g., 'https://dex.accuser.dev/dex'). Must be accessible by clients."
  type        = string
  default     = ""
}

variable "dex_github_client_id" {
  description = "GitHub OAuth application client ID for Dex"
  type        = string
  default     = ""
}

variable "dex_github_client_secret" {
  description = "GitHub OAuth application client secret for Dex"
  type        = string
  sensitive   = true
  default     = ""
}

variable "dex_github_allowed_orgs" {
  description = "List of GitHub organizations allowed to authenticate via Dex. Empty means all users."
  type        = list(string)
  default     = []
}

variable "openfga_preshared_key" {
  description = "Preshared key for OpenFGA API authentication. Used by Incus to communicate with OpenFGA."
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# HAProxy Configuration
# =============================================================================

variable "enable_haproxy" {
  description = "Enable HAProxy load balancer for Incus cluster"
  type        = bool
  default     = false
}

variable "haproxy_stats_password" {
  description = "Password for HAProxy stats interface"
  type        = string
  sensitive   = true
  default     = ""
}

variable "incus_cluster_nodes" {
  description = "List of Incus cluster node IP addresses for HAProxy backend"
  type        = list(string)
  default     = []
}

# =============================================================================
# OVN Configuration
# =============================================================================

variable "network_backend" {
  description = "Network backend: 'bridge' (default) or 'ovn' for overlay networking with cross-environment connectivity"
  type        = string
  default     = "bridge"

  validation {
    condition     = contains(["bridge", "ovn"], var.network_backend)
    error_message = "network_backend must be 'bridge' or 'ovn'."
  }
}

variable "ovn_uplink_network" {
  description = "Uplink network name for OVN external connectivity. Must be created manually before enabling OVN."
  type        = string
  default     = "ovn-uplink"
}

variable "ovn_integration" {
  description = "Network integration name for cross-server OVN connectivity. Leave empty for local-only OVN."
  type        = string
  default     = ""
}

variable "ovn_production_external" {
  description = "Use an existing OVN production network instead of creating one. Set to true when sharing ovn-production with another environment (e.g., cluster01)."
  type        = bool
  default     = false
}

variable "skip_ovn_config" {
  description = "Skip OVN daemon configuration (set to true if OVN is already configured via CLI)"
  type        = bool
  default     = false
}

variable "ovn_central_host_address" {
  description = "Physical network IP for OVN central proxy devices. This is where other chassis connect to OVN databases."
  type        = string
  default     = ""
}

# OVN Load Balancer VIP Addresses
variable "grafana_lb_address" {
  description = "OVN load balancer VIP for Grafana. Must be in uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

variable "prometheus_lb_address" {
  description = "OVN load balancer VIP for Prometheus. Must be in uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

variable "loki_lb_address" {
  description = "OVN load balancer VIP for Loki. Must be in uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

variable "step_ca_lb_address" {
  description = "OVN load balancer VIP for step-ca. Must be in uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

variable "coredns_lb_address" {
  description = "OVN load balancer VIP for CoreDNS. Must be in uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

variable "atlantis_lb_address" {
  description = "OVN load balancer VIP for Atlantis. Must be in uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

# =============================================================================
# Cross-Environment Integration
# =============================================================================

variable "cluster01_prometheus_url" {
  description = "URL of cluster01 Prometheus for federation (e.g., 'http://192.168.68.13:9090'). Leave empty to disable federation."
  type        = string
  default     = ""
}

variable "cluster01_alertmanager_url" {
  description = "URL of cluster01 Alertmanager (e.g., 'http://192.168.68.18:9093'). Leave empty to disable alerting."
  type        = string
  default     = ""
}

variable "cluster01_coredns_address" {
  description = "IP address of cluster01 CoreDNS for cross-environment DNS resolution (e.g., cluster01.incus zone). Use the OVN LB VIP or direct container IP."
  type        = string
  default     = ""
}

variable "cluster01_dns_zone_name" {
  description = "Incus DNS zone name for cluster01 (e.g., 'cluster01.incus'). Used for cross-environment forwarding."
  type        = string
  default     = "cluster01.incus"
}

