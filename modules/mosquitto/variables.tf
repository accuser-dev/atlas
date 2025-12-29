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
  default     = "images:alpine/3.21/cloud"
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
  default     = ["default"]
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
  description = "Enable external access via Incus proxy devices. Set to false when using OVN load balancers or when production network is physical (direct LAN attachment)."
  type        = bool
  default     = true
}

variable "use_ovn_lb" {
  description = "Use OVN load balancer instead of proxy devices for external access. When true, proxy devices are not created and access should be configured via the ovn-load-balancer module."
  type        = bool
  default     = false
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
  description = "Duration for TLS certificates (e.g., 24h, 168h). Must be between 1h and 8760h (1 year)."
  type        = string
  default     = "24h"

  validation {
    condition     = can(regex("^[0-9]+h$", var.cert_duration))
    error_message = "Certificate duration must be in hours format (e.g., '24h', '168h')."
  }

  validation {
    condition     = tonumber(trimsuffix(var.cert_duration, "h")) >= 1 && tonumber(trimsuffix(var.cert_duration, "h")) <= 8760
    error_message = "Certificate duration must be between 1h and 8760h (1 year)."
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

# Snapshot Scheduling
variable "enable_snapshots" {
  description = "Enable automatic snapshots for the data volume"
  type        = bool
  default     = false
}

variable "snapshot_schedule" {
  description = "Cron expression or shorthand (@hourly, @daily, @weekly) for snapshot schedule"
  type        = string
  default     = "@daily"

  validation {
    condition     = can(regex("^(@(hourly|daily|weekly|monthly)|[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+)$", var.snapshot_schedule))
    error_message = "Must be a valid cron expression or shorthand (@hourly, @daily, @weekly, @monthly)"
  }
}

variable "snapshot_expiry" {
  description = "How long to keep snapshots (e.g., 7d, 4w, 3m)"
  type        = string
  default     = "7d"

  validation {
    condition     = can(regex("^[0-9]+(d|w|m)$", var.snapshot_expiry))
    error_message = "Must be in format like '7d' (days), '4w' (weeks), or '3m' (months)"
  }
}

variable "snapshot_pattern" {
  description = "Naming pattern for snapshots (supports {{creation_date}})"
  type        = string
  default     = "auto-{{creation_date}}"
}
