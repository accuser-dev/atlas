variable "instance_name" {
  description = "Name of the Mosquitto instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "ghcr:accuser/atlas/mosquitto:latest"
}

variable "cpu_limit" {
  description = "CPU limit for the container"
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
  default     = "256MB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '256MB' or '1GB'"
  }
}

variable "storage_pool" {
  description = "Storage pool for the data volume"
  type        = string
  default     = "local"
}

variable "profiles" {
  description = "List of Incus profile names to apply (should include base profiles for root disk and network)"
  type        = list(string)
  default     = ["default"]
}

variable "environment_variables" {
  description = "Environment variables for Mosquitto container"
  type        = map(string)
  default     = {}
}

variable "enable_data_persistence" {
  description = "Enable persistent storage for Mosquitto data"
  type        = bool
  default     = false
}

variable "data_volume_name" {
  description = "Name of the storage volume for Mosquitto data"
  type        = string
  default     = "mosquitto-data"
}

variable "data_volume_size" {
  description = "Size of the storage volume (e.g., 5GB). Minimum recommended: 100MB"
  type        = string
  default     = "5GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '5GB' or '500MB'"
  }

  validation {
    condition = (
      can(regex("TB$", var.data_volume_size)) ||
      can(regex("GB$", var.data_volume_size)) ||
      (can(regex("MB$", var.data_volume_size)) && tonumber(regex("^[0-9]+", var.data_volume_size)) >= 100)
    )
    error_message = "Mosquitto volume size must be at least 100MB for retained messages"
  }
}

# MQTT Port Configuration
variable "mqtt_port" {
  description = "Internal port for plain MQTT"
  type        = string
  default     = "1883"

  validation {
    condition     = can(regex("^[0-9]+$", var.mqtt_port)) && tonumber(var.mqtt_port) >= 1 && tonumber(var.mqtt_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

variable "mqtts_port" {
  description = "Internal port for MQTT over TLS"
  type        = string
  default     = "8883"

  validation {
    condition     = can(regex("^[0-9]+$", var.mqtts_port)) && tonumber(var.mqtts_port) >= 1 && tonumber(var.mqtts_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

# External Access via Proxy Devices
variable "enable_external_access" {
  description = "Enable external access via Incus proxy devices"
  type        = bool
  default     = true
}

variable "external_mqtt_port" {
  description = "Host port for external MQTT access (via proxy device)"
  type        = string
  default     = "1883"

  validation {
    condition     = can(regex("^[0-9]+$", var.external_mqtt_port)) && tonumber(var.external_mqtt_port) >= 1 && tonumber(var.external_mqtt_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

variable "external_mqtts_port" {
  description = "Host port for external MQTTS access (via proxy device)"
  type        = string
  default     = "8883"

  validation {
    condition     = can(regex("^[0-9]+$", var.external_mqtts_port)) && tonumber(var.external_mqtts_port) >= 1 && tonumber(var.external_mqtts_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

# TLS Configuration
variable "enable_tls" {
  description = "Enable TLS for Mosquitto using step-ca"
  type        = bool
  default     = false
}

variable "stepca_url" {
  description = "URL of the step-ca server (required if enable_tls is true)"
  type        = string
  default     = ""
}

variable "stepca_fingerprint" {
  description = "Fingerprint of the step-ca root certificate (required if enable_tls is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cert_duration" {
  description = "Duration for TLS certificates (e.g., 24h, 168h)"
  type        = string
  default     = "24h"

  validation {
    condition     = can(regex("^[0-9]+h$", var.cert_duration))
    error_message = "Certificate duration must be in hours format (e.g., '24h', '168h')"
  }
}

# Authentication
variable "mqtt_users" {
  description = "Map of MQTT users and passwords for authentication. If empty, anonymous access is allowed."
  type        = map(string)
  default     = {}
  sensitive   = true
}

# Custom Configuration
variable "mosquitto_config" {
  description = "Custom Mosquitto configuration to append (optional)"
  type        = string
  default     = ""
}
