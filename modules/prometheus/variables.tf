variable "instance_name" {
  description = "Name of the Prometheus instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "docker:prom/prometheus"
}

variable "cpu_limit" {
  description = "CPU limit for the container"
  type        = string
  default     = "2"
}

variable "memory_limit" {
  description = "Memory limit for the container"
  type        = string
  default     = "2GB"
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
  description = "Environment variables for Prometheus container"
  type        = map(string)
  default     = {}
}

variable "enable_data_persistence" {
  description = "Enable persistent storage for Prometheus data"
  type        = bool
  default     = false
}

variable "data_volume_name" {
  description = "Name of the storage volume for Prometheus data"
  type        = string
  default     = "prometheus-data"
}

variable "data_volume_size" {
  description = "Size of the storage volume (e.g., 100GB)"
  type        = string
  default     = "100GB"
}

variable "prometheus_port" {
  description = "Port that Prometheus listens on"
  type        = string
  default     = "9090"
}

variable "prometheus_config" {
  description = "Prometheus configuration file content (prometheus.yml)"
  type        = string
  default     = ""
}
