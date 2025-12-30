# =============================================================================
# Mosquitto MQTT Broker Module
# =============================================================================
# Uses Alpine Linux system container with cloud-init for configuration

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    mqtt_port          = var.mqtt_port
    mqtts_port         = var.mqtts_port
    enable_tls         = var.enable_tls
    stepca_url         = var.stepca_url
    stepca_fingerprint = var.stepca_fingerprint
    cert_duration      = var.cert_duration
    mqtt_users         = var.mqtt_users
    mosquitto_config   = var.mosquitto_config
  })
}

resource "incus_storage_volume" "mosquitto_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = var.data_volume_name
  pool    = var.storage_pool
  project = "default"

  config = merge(
    {
      size = var.data_volume_size
      # Set initial ownership for mosquitto user (Alpine package uses UID 100, GID 101)
      "initial.uid"  = "100"
      "initial.gid"  = "101"
      "initial.mode" = "0755"
    },
    var.enable_snapshots ? {
      "snapshots.schedule" = var.snapshot_schedule
      "snapshots.expiry"   = var.snapshot_expiry
      "snapshots.pattern"  = var.snapshot_pattern
    } : {}
  )

  content_type = "filesystem"
}

# Service-specific profile
# Contains resource limits, root disk with size limit, and service-specific devices
# Network is provided by profiles passed via var.profiles
resource "incus_profile" "mosquitto" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
  }

  # Root disk with size limit
  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
      size = var.root_disk_size
    }
  }

  # Persistent storage for MQTT data (retained messages, etc.)
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "mosquitto-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.mosquitto_data[0].name
        pool   = var.storage_pool
        path   = "/mosquitto/data"
      }
    }
  }

  # External access via proxy device for plain MQTT
  # Disabled when using OVN load balancer (use_ovn_lb = true)
  dynamic "device" {
    for_each = var.enable_external_access && !var.use_ovn_lb ? [1] : []
    content {
      name = "mqtt-proxy"
      type = "proxy"
      properties = {
        listen  = "tcp:0.0.0.0:${var.external_mqtt_port}"
        connect = "tcp:127.0.0.1:${var.mqtt_port}"
        bind    = "host"
      }
    }
  }

  # External access via proxy device for MQTT over TLS
  # Disabled when using OVN load balancer (use_ovn_lb = true)
  dynamic "device" {
    for_each = var.enable_external_access && var.enable_tls && !var.use_ovn_lb ? [1] : []
    content {
      name = "mqtts-proxy"
      type = "proxy"
      properties = {
        listen  = "tcp:0.0.0.0:${var.external_mqtts_port}"
        connect = "tcp:127.0.0.1:${var.mqtts_port}"
        bind    = "host"
      }
    }
  }

  depends_on = [
    incus_storage_volume.mosquitto_data
  ]
}

resource "incus_instance" "mosquitto" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.mosquitto.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  lifecycle {
    precondition {
      condition     = !var.enable_tls || (var.stepca_url != "" && var.stepca_fingerprint != "")
      error_message = "When enable_tls is true, both stepca_url and stepca_fingerprint must be provided."
    }
  }
}
