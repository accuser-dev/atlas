variable "instance_name" {
  description = "Name of the Loki instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "docker:grafana/loki"
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
  description = "Environment variables for Loki container"
  type        = map(string)
  default     = {}
}

variable "enable_data_persistence" {
  description = "Enable persistent storage for Loki data"
  type        = bool
  default     = false
}

variable "data_volume_name" {
  description = "Name of the storage volume for Loki data"
  type        = string
  default     = "loki-data"
}

variable "data_volume_size" {
  description = "Size of the storage volume (e.g., 50GB)"
  type        = string
  default     = "50GB"
}

variable "loki_port" {
  description = "Port that Loki listens on"
  type        = string
  default     = "3100"
}
