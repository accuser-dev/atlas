variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cloudflare_api_token) >= 40
    error_message = "Cloudflare API token appears invalid (must be at least 40 characters)"
  }
}

# Access Control
variable "allowed_ip_range" {
  description = "IP range allowed to access public services (CIDR notation). Set to your home/office network for security. Required - no default for security reasons."
  type        = string
  # No default - must be explicitly set for security

  validation {
    condition     = can(cidrhost(var.allowed_ip_range, 0))
    error_message = "Must be valid CIDR notation (e.g., 192.168.1.0/24 or 0.0.0.0/0)"
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
variable "production_network_ipv4" {
  description = "IPv4 address for production network (public-facing services)"
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

variable "atlantis_allowed_ip_range" {
  description = "IP range allowed to access Atlantis webhook (default: GitHub webhook IPs)"
  type        = string
  default     = "192.30.252.0/22 185.199.108.0/22 140.82.112.0/20 143.55.64.0/20"
}
