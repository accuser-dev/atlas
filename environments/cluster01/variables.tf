# =============================================================================
# Incus Remote Configuration
# =============================================================================
# The Incus remote is configured via:
#   - incus remote switch cluster01
#   - INCUS_REMOTE=cluster01 environment variable

variable "accept_remote_certificate" {
  description = "Automatically accept remote server certificate (use with caution)"
  type        = bool
  default     = false
}

# =============================================================================
# Network Configuration
# =============================================================================
# Note: Cluster node names are discovered dynamically via the Incus API
# See main.tf for the external data source that queries cluster membership

variable "production_network_name" {
  description = "Name of the production network"
  type        = string
  default     = "production"
}

variable "production_network_type" {
  description = "Type of production network (bridge or physical)"
  type        = string
  default     = "bridge"

  validation {
    condition     = contains(["bridge", "physical"], var.production_network_type)
    error_message = "production_network_type must be 'bridge' or 'physical'"
  }
}

variable "production_network_parent" {
  description = "Parent interface for physical network mode (e.g., 'eno1')"
  type        = string
  default     = ""
}

variable "production_network_ipv4" {
  description = "IPv4 CIDR for production network (bridge mode only)"
  type        = string
  default     = "10.10.0.1/24"
}

variable "production_network_nat" {
  description = "Enable NAT on production network (bridge mode only)"
  type        = bool
  default     = true
}

variable "production_network_ipv6" {
  description = "IPv6 CIDR for production network (bridge mode, empty to disable)"
  type        = string
  default     = ""
}

variable "production_network_ipv6_nat" {
  description = "Enable NAT66 on production network (bridge mode only)"
  type        = bool
  default     = false
}

variable "management_network_name" {
  description = "Name of the management network. On clusters, use the existing bridge (e.g., 'incusbr0')."
  type        = string
  default     = "incusbr0"
}

variable "management_network_ipv4" {
  description = "IPv4 CIDR for management network (not used when using external network)"
  type        = string
  default     = "10.20.0.1/24"
}

variable "management_network_nat" {
  description = "Enable NAT on management network"
  type        = bool
  default     = true
}

variable "management_network_ipv6" {
  description = "IPv6 CIDR for management network (empty to disable)"
  type        = string
  default     = ""
}

variable "management_network_ipv6_nat" {
  description = "Enable NAT66 on management network"
  type        = bool
  default     = false
}

# =============================================================================
# Cross-Environment Integration
# =============================================================================

variable "loki_push_url" {
  description = "URL of central Loki instance on iapetus for log shipping (e.g., http://loki01.iapetus:3100/loki/api/v1/push)"
  type        = string
}

variable "step_ca_url" {
  description = "URL of central step-ca instance on iapetus (e.g., https://step-ca01.iapetus:9000)"
  type        = string
  default     = ""
}

variable "step_ca_fingerprint" {
  description = "CA fingerprint from iapetus step-ca for TLS trust"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# DNS Configuration
# =============================================================================

variable "dns_domain" {
  description = "Internal DNS domain for services"
  type        = string
  default     = "cluster.local"
}

variable "dns_upstream_servers" {
  description = "Upstream DNS servers for forwarding"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "dns_nameserver_ip" {
  description = "IP address for the NS record (physical mode)"
  type        = string
  default     = ""
}

variable "dns_additional_records" {
  description = "Additional static DNS records"
  type = list(object({
    name  = string
    type  = string
    value = string
    ttl   = optional(number, 300)
  }))
  default = []
}

variable "iapetus_coredns_address" {
  description = "IP address of iapetus CoreDNS for cross-environment DNS resolution (e.g., iapetus.incus zone). Use the OVN LB VIP or direct container IP."
  type        = string
  default     = ""
}

variable "iapetus_dns_zone_name" {
  description = "Incus DNS zone name for iapetus (e.g., 'iapetus.incus'). Used for cross-environment forwarding."
  type        = string
  default     = "iapetus.incus"
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
  description = "Incus DNS zone name for this cluster (e.g., 'cluster01.incus'). Containers will be registered as <name>.<zone>."
  type        = string
  default     = "cluster01.incus"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.incus_dns_zone_name))
    error_message = "Zone name must be a valid DNS domain (lowercase, alphanumeric with dots and hyphens)"
  }
}

variable "incus_dns_listen_address" {
  description = "Address for Incus DNS server to listen on. Use ':5353' to bind all interfaces. Must be an IP the host actually has."
  type        = string
  default     = ":5353"
}

variable "incus_dns_reachable_address" {
  description = "Address where CoreDNS can reach the Incus DNS server for zone transfers. For clusters, use a node's IP with port (e.g., '192.168.71.5:5353')."
  type        = string
  default     = ""
}

variable "incus_dns_transfer_peer_ip" {
  description = "Source IP that the Incus host sees for CoreDNS zone transfer requests. Required for zone transfers to work."
  type        = string
  default     = ""
}

# =============================================================================
# Incus Integration
# =============================================================================

variable "enable_incus_metrics" {
  description = "Enable Incus container metrics scraping"
  type        = bool
  default     = true
}

variable "incus_metrics_address" {
  description = "Address of the Incus metrics endpoint"
  type        = string
  default     = "127.0.0.1:8443"
}

variable "incus_metrics_server_name" {
  description = "TLS server name for Incus metrics (ACME domain, empty to skip verification)"
  type        = string
  default     = ""
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

variable "mosquitto_lb_address" {
  description = "OVN load balancer VIP for Mosquitto (e.g., '192.168.68.10'). Must be in the uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

variable "coredns_lb_address" {
  description = "OVN load balancer VIP for CoreDNS (e.g., '192.168.68.11'). Must be in the uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

variable "alloy_syslog_lb_address" {
  description = "OVN load balancer VIP for Alloy syslog receiver (e.g., '192.168.68.12'). Must be in the uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

variable "prometheus_lb_address" {
  description = "OVN load balancer VIP for Prometheus (e.g., '192.168.68.13'). Enables federation from iapetus."
  type        = string
  default     = ""
}

variable "forgejo_lb_address" {
  description = "OVN load balancer VIP for Forgejo (e.g., '192.168.68.14'). Must be in the uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

# Note: OVN northbound connection is provided by the ovn-central container module
# when network_backend = "ovn". No manual configuration required.

variable "skip_ovn_config" {
  description = "Skip OVN daemon configuration (set to true if OVN is already configured via CLI or has ETag issues in clusters)"
  type        = bool
  default     = false
}

# =============================================================================
# Ceph Storage Configuration
# =============================================================================

variable "enable_ceph" {
  description = "Enable Ceph distributed storage cluster"
  type        = bool
  default     = false
}

variable "ceph_storage_network_name" {
  description = "Name of the storage network for Ceph (must be pre-configured on IncusOS)"
  type        = string
  default     = "storage"
}

variable "ceph_public_network" {
  description = "Public network CIDR for Ceph client traffic"
  type        = string
  default     = "10.40.0.0/24"
}

variable "ceph_cluster_network" {
  description = "Cluster network CIDR for OSD replication (defaults to public network)"
  type        = string
  default     = ""
}

variable "ceph_osd_devices" {
  description = "Map of cluster node names to their OSD block device paths"
  type        = map(string)
  default     = {}
  # Example: { "node01" = "/dev/disk/by-id/wwn-...", "node02" = "/dev/disk/by-id/wwn-...", "node03" = "/dev/disk/by-id/wwn-..." }
}

variable "ceph_mon_ips" {
  description = "Map of cluster node names to MON static IPs on the storage network"
  type        = map(string)
  default     = {}
  # Example: { "node01" = "10.40.0.11", "node02" = "10.40.0.12", "node03" = "10.40.0.13" }
}

variable "ceph_mgr_ips" {
  description = "Map of cluster node names to MGR static IPs on the storage network"
  type        = map(string)
  default     = {}
  # Example: { "node01" = "10.40.0.21" }
}

variable "ceph_osd_ips" {
  description = "Map of cluster node names to OSD static IPs on the storage network"
  type        = map(string)
  default     = {}
  # Example: { "node01" = "10.40.0.31", "node02" = "10.40.0.32", "node03" = "10.40.0.33" }
}

variable "ceph_rgw_ips" {
  description = "Map of cluster node names to RGW static IPs on the storage network"
  type        = map(string)
  default     = {}
  # Example: { "node01" = "10.40.0.41" }
}

variable "ceph_cluster_fsid" {
  description = "Ceph cluster FSID (leave empty to auto-generate)"
  type        = string
  default     = ""
}

variable "ceph_rgw_lb_address" {
  description = "OVN load balancer VIP for Ceph RGW S3 API (e.g., '192.168.68.18'). Must be in the uplink's ipv4.ovn.ranges."
  type        = string
  default     = ""
}

# =============================================================================
# PostgreSQL Configuration
# =============================================================================

variable "enable_postgresql" {
  description = "Enable PostgreSQL database server"
  type        = bool
  default     = false
}

variable "postgresql_admin_password" {
  description = "PostgreSQL admin (postgres) password"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Forgejo Configuration
# =============================================================================

variable "enable_forgejo" {
  description = "Enable Forgejo Git forge"
  type        = bool
  default     = false
}

variable "forgejo_admin_username" {
  description = "Forgejo admin username"
  type        = string
  default     = "forge_admin"  # "admin" is reserved in Forgejo
}

variable "forgejo_admin_password" {
  description = "Forgejo admin password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "forgejo_admin_email" {
  description = "Forgejo admin email"
  type        = string
  default     = "admin@example.com"
}

variable "forgejo_db_password" {
  description = "Password for Forgejo database user"
  type        = string
  default     = ""
  sensitive   = true
}

variable "forgejo_domain" {
  description = "Domain name for Forgejo (e.g., 'git.example.com')"
  type        = string
  default     = "localhost"
}

variable "forgejo_proxy_stats_password" {
  description = "Password for HAProxy stats interface (Forgejo reverse proxy)"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Forgejo Runner Configuration
# =============================================================================

variable "enable_forgejo_runner" {
  description = "Enable Forgejo Actions runner"
  type        = bool
  default     = false
}

variable "forgejo_runner_labels" {
  description = "Labels for the Forgejo runner (e.g., 'debian-trixie:host,linux_amd64:host')"
  type        = string
  default     = "debian-trixie:host,linux_amd64:host"
}

variable "forgejo_runner_insecure" {
  description = "Skip TLS verification for Forgejo runner connection (useful for self-signed certs)"
  type        = bool
  default     = false
}
