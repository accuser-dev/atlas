# =============================================================================
# Mosquitto MQTT Broker Module
# =============================================================================
# Supports two container types:
# - system: Alpine Linux with cloud-init (recommended)
# - oci: Docker/OCI image from ghcr.io (legacy)

locals {
  # Select image based on container type if not explicitly provided
  default_images = {
    system = "images:alpine/3.21/cloud"
    oci    = "ghcr:accuser-dev/atlas/mosquitto:latest"
  }
  selected_image = var.image != "" ? var.image : local.default_images[var.container_type]

  # Mosquitto user UID differs between Alpine package (100) and OCI image (1883)
  mosquitto_uid = var.container_type == "system" ? "100" : "1883"
  mosquitto_gid = var.container_type == "system" ? "101" : "1883"

  # TLS environment variables (only for OCI containers)
  tls_env_vars = var.container_type == "oci" && var.enable_tls ? {
    ENABLE_TLS         = "true"
    STEPCA_URL         = var.stepca_url
    STEPCA_FINGERPRINT = var.stepca_fingerprint
    CERT_DURATION      = var.cert_duration
  } : {}

  # Port environment variables (only for OCI containers)
  port_env_vars = var.container_type == "oci" ? {
    MQTT_PORT  = var.mqtt_port
    MQTTS_PORT = var.mqtts_port
  } : {}

  # Password file content (for OCI container file injection)
  passwd_content = length(var.mqtt_users) > 0 ? join("\n", [
    for username, password in var.mqtt_users : "${username}:${password}"
  ]) : ""

  # Cloud-init configuration (for system containers)
  cloud_init_content = var.container_type == "system" ? templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    mqtt_port          = var.mqtt_port
    mqtts_port         = var.mqtts_port
    enable_tls         = var.enable_tls
    stepca_url         = var.stepca_url
    stepca_fingerprint = var.stepca_fingerprint
    cert_duration      = var.cert_duration
    mqtt_users         = var.mqtt_users
    mosquitto_config   = var.mosquitto_config
  }) : ""
}

resource "incus_storage_volume" "mosquitto_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = merge(
    {
      size = var.data_volume_size
      # Set initial ownership for mosquitto user to allow writes from non-root container
      # UID differs: Alpine package uses 100, OCI image uses 1883
      "initial.uid"  = local.mosquitto_uid
      "initial.gid"  = local.mosquitto_gid
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
  dynamic "device" {
    for_each = var.enable_external_access ? [1] : []
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
  dynamic "device" {
    for_each = var.enable_external_access && var.enable_tls ? [1] : []
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
  image    = local.selected_image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.mosquitto.name])

  # Configuration differs based on container type
  config = var.container_type == "system" ? {
    # System container: use cloud-init for configuration
    "cloud-init.user-data" = local.cloud_init_content
  } : merge(
    # OCI container: use environment variables
    { for k, v in var.environment_variables : "environment.${k}" => v },
    { for k, v in local.tls_env_vars : "environment.${k}" => v },
    { for k, v in local.port_env_vars : "environment.${k}" => v },
  )

  # File injection only for OCI containers (system containers use cloud-init)
  dynamic "file" {
    for_each = var.container_type == "oci" && length(var.mqtt_users) > 0 ? [1] : []
    content {
      content     = local.passwd_content
      target_path = "/mosquitto/config/passwd"
      mode        = "0640"
    }
  }

  dynamic "file" {
    for_each = var.container_type == "oci" && var.mosquitto_config != "" ? [1] : []
    content {
      content     = var.mosquitto_config
      target_path = "/mosquitto/config/custom.conf"
      mode        = "0644"
    }
  }

  lifecycle {
    precondition {
      condition     = !var.enable_tls || (var.stepca_url != "" && var.stepca_fingerprint != "")
      error_message = "When enable_tls is true, both stepca_url and stepca_fingerprint must be provided."
    }
  }
}
