variable "instance_name" {
  description = "Name of the Grafana instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "docker:grafana/grafana"
}

variable "cpu_limit" {
  description = "CPU limit for the container"
  type        = string
  default     = "2"
}

variable "memory_limit" {
  description = "Memory limit for the container"
  type        = string
  default     = "1GB"
}

variable "storage_pool" {
  description = "Storage pool for the root disk"
  type        = string
  default     = "default"
}

variable "monitoring_network" {
  description = "Monitoring network name"
  type        = string
  default     = "monitoring"
}

variable "environment_variables" {
  description = "Environment variables for Grafana container"
  type        = map(string)
  default     = {}
}

variable "enable_data_persistence" {
  description = "Enable persistent storage for Grafana data"
  type        = bool
  default     = false
}

variable "data_volume_name" {
  description = "Name of the storage volume for Grafana data"
  type        = string
  default     = "grafana-data"
}

variable "data_volume_size" {
  description = "Size of the storage volume (e.g., 10GB)"
  type        = string
  default     = "10GB"
}

variable "domain" {
  description = "Domain name for Grafana (for reverse proxy configuration)"
  type        = string
  default     = ""
}

variable "allowed_ip_range" {
  description = "IP range allowed to access Grafana (CIDR notation)"
  type        = string
  default     = "192.168.68.0/22"
}

variable "grafana_port" {
  description = "Port that Grafana listens on"
  type        = string
  default     = "3000"
}

