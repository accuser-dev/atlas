# =============================================================================
# Instance Configuration
# =============================================================================

variable "instance_name" {
  description = "Name of the CoreDNS container instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile to create"
  type        = string
}

variable "image" {
  description = "Container image to use for CoreDNS (system container with cloud-init)"
  type        = string
  default     = "images:alpine/3.21/cloud"
}

variable "cpu_limit" {
  description = "CPU limit for the container (number of cores)"
  type        = string
  default     = "1"

  validation {
    condition     = can(regex("^[0-9]+$", var.cpu_limit)) && tonumber(var.cpu_limit) >= 1 && tonumber(var.cpu_limit) <= 64
    error_message = "CPU limit must be a number between 1 and 64"
  }
}

variable "memory_limit" {
  description = "Memory limit for the container"
  type        = string
  default     = "128MB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '128MB' or '1GB'"
  }
}

variable "storage_pool" {
  description = "Storage pool for volumes"
  type        = string
  default     = "local"
}

variable "root_disk_size" {
  description = "Size limit for the root disk (container filesystem)"
  type        = string
  default     = "1GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '1GB' or '500MB'"
  }
}

variable "profiles" {
  description = "List of Incus profile names to apply (should include base profile and network profile)"
  type        = list(string)
  default     = []
}

variable "ipv4_address" {
  description = "Static IPv4 address for the container (e.g., '10.10.0.53'). Leave empty for DHCP."
  type        = string
  default     = ""
}

variable "ipv4_gateway" {
  description = "Gateway IP for static IP configuration (e.g., '10.10.0.1'). Required when ipv4_address is set."
  type        = string
  default     = ""
}

variable "static_ip_dns_servers" {
  description = "DNS servers for the container when using static IP. Defaults to upstream DNS servers."
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1"]
}

# =============================================================================
# DNS Port Configuration
# =============================================================================

variable "dns_port" {
  description = "Internal port for DNS queries"
  type        = string
  default     = "53"
}

variable "health_port" {
  description = "Port for health check endpoint"
  type        = string
  default     = "8080"
}

# =============================================================================
# Zone Configuration
# =============================================================================

variable "domain" {
  description = "Primary domain for the authoritative zone (e.g., accuser.dev)"
  type        = string
}

variable "dns_records" {
  description = "List of DNS records for the zone file. Each service module outputs its records."
  type = list(object({
    name  = string # Hostname without domain (e.g., "grafana")
    type  = string # Record type: A, AAAA, CNAME
    value = string # IP address or target hostname
    ttl   = optional(number, 300)
  }))
  default = []
}

variable "additional_records" {
  description = "Additional static DNS records not managed by service modules"
  type = list(object({
    name  = string
    type  = string
    value = string
    ttl   = optional(number, 300)
  }))
  default = []
}

variable "soa_nameserver" {
  description = "Primary nameserver hostname for SOA record (without domain suffix)"
  type        = string
  default     = "ns1"
}

variable "soa_admin" {
  description = "Admin email for SOA record (use dots instead of @, e.g., 'admin' becomes admin.<domain>)"
  type        = string
  default     = "admin"
}

variable "zone_ttl" {
  description = "Default TTL for the zone in seconds"
  type        = number
  default     = 300
}

variable "nameserver_ip" {
  description = "IP address for the NS record (typically the CoreDNS container's IP on production network)"
  type        = string
}

# =============================================================================
# Forwarding Configuration
# =============================================================================

variable "incus_dns_server" {
  description = "Incus DNS server address for .incus domain resolution (typically management network gateway)"
  type        = string
  default     = "10.20.0.1"
}

variable "upstream_dns_servers" {
  description = "List of upstream DNS servers for external domain resolution"
  type        = list(string)
  default     = ["1.1.1.1", "1.0.0.1"]
}

# =============================================================================
# External Access Configuration
# =============================================================================

variable "enable_external_access" {
  description = "Enable external access via Incus proxy devices. Set to false when using OVN load balancers or when production network is physical (direct LAN attachment)."
  type        = bool
  default     = true
}

variable "use_ovn_lb" {
  description = "Use OVN load balancer instead of proxy devices for external access. When true, proxy devices are not created and access should be configured via the ovn-load-balancer module."
  type        = bool
  default     = false
}

variable "external_dns_port" {
  description = "Host port for external DNS access (via proxy device). Only used when enable_external_access is true."
  type        = string
  default     = "53"
}

# =============================================================================
# Secondary Zone Configuration (AXFR)
# =============================================================================

variable "secondary_zones" {
  description = "List of secondary zones to pull via AXFR zone transfer from external DNS servers (e.g., Incus DNS)"
  type = list(object({
    zone   = string # Zone name (e.g., "incus.accuser.dev")
    master = string # Master DNS server address with port (e.g., "10.20.0.1:5354")
  }))
  default = []
}

variable "secondary_zone_cache_ttl" {
  description = "Cache TTL for secondary zones in seconds (shorter than primary due to dynamic container IPs)"
  type        = number
  default     = 60

  validation {
    condition     = var.secondary_zone_cache_ttl >= 10 && var.secondary_zone_cache_ttl <= 3600
    error_message = "Secondary zone cache TTL must be between 10 and 3600 seconds"
  }
}

# =============================================================================
# Forwarding Zone Configuration
# =============================================================================

variable "forward_zones" {
  description = "List of zones to forward to specific DNS servers (e.g., for cross-environment DNS)"
  type = list(object({
    zone    = string       # Zone name (e.g., "incus.accuser.dev")
    servers = list(string) # DNS servers to forward to (e.g., ["192.168.68.4"])
  }))
  default = []
}

variable "forward_zone_cache_ttl" {
  description = "Cache TTL for forwarded zones in seconds"
  type        = number
  default     = 60

  validation {
    condition     = var.forward_zone_cache_ttl >= 10 && var.forward_zone_cache_ttl <= 3600
    error_message = "Forward zone cache TTL must be between 10 and 3600 seconds"
  }
}
