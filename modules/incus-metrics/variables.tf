variable "certificate_name" {
  description = "Name for the metrics certificate in Incus"
  type        = string
  default     = "prometheus-metrics"
}

variable "certificate_description" {
  description = "Description for the metrics certificate"
  type        = string
  default     = "Metrics certificate for Prometheus scraping"
}

variable "certificate_validity_days" {
  description = "Number of days the certificate is valid"
  type        = number
  default     = 3650

  validation {
    condition     = var.certificate_validity_days >= 1 && var.certificate_validity_days <= 7300
    error_message = "Certificate validity must be between 1 and 7300 days (20 years)"
  }
}

variable "certificate_common_name" {
  description = "Common name for the certificate"
  type        = string
  default     = "metrics.local"
}

variable "incus_server_address" {
  description = "Address of the Incus server for metrics endpoint (e.g., 'incus.local:8443' or '10.0.0.1:8443')"
  type        = string
}

variable "incus_server_name" {
  description = "Server name for TLS verification (must match certificate SAN). Usually the hostname portion of incus_server_address."
  type        = string
  default     = ""
}
