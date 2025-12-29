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

# Note: OVN northbound connection is provided by the ovn-central container module
# when network_backend = "ovn". No manual configuration required.

variable "skip_ovn_config" {
  description = "Skip OVN daemon configuration (set to true if OVN is already configured via CLI or has ETag issues in clusters)"
  type        = bool
  default     = false
}
