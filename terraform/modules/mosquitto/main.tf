resource "incus_storage_volume" "mosquitto_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = merge(
    {
      size = var.data_volume_size
      # Set initial ownership for mosquitto user (UID 1883) to allow writes from non-root container
      # Requires Incus 6.8+ (https://linuxcontainers.org/incus/news/2024_12_13_07_12.html)
      "initial.uid"  = "1883"
      "initial.gid"  = "1883"
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

locals {
  # TLS environment variables (only set when TLS is enabled)
  tls_env_vars = var.enable_tls ? {
    ENABLE_TLS         = "true"
    STEPCA_URL         = var.stepca_url
    STEPCA_FINGERPRINT = var.stepca_fingerprint
    CERT_DURATION      = var.cert_duration
  } : {}

  # Port environment variables
  port_env_vars = {
    MQTT_PORT  = var.mqtt_port
    MQTTS_PORT = var.mqtts_port
  }

  # Generate password file content if users are provided
  # Format: username:password_hash (one per line)
  # Note: The container will need to hash these - for now we pass plaintext
  # and the entrypoint can use mosquitto_passwd if needed
  passwd_content = length(var.mqtt_users) > 0 ? join("\n", [
    for username, password in var.mqtt_users : "${username}:${password}"
  ]) : ""
}

resource "incus_instance" "mosquitto" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.mosquitto.name])

  config = merge(
    { for k, v in var.environment_variables : "environment.${k}" => v },
    { for k, v in local.tls_env_vars : "environment.${k}" => v },
    { for k, v in local.port_env_vars : "environment.${k}" => v },
  )

  # Inject password file if users are configured
  dynamic "file" {
    for_each = length(var.mqtt_users) > 0 ? [1] : []
    content {
      content     = local.passwd_content
      target_path = "/mosquitto/config/passwd"
      mode        = "0640"
    }
  }

  # Inject custom configuration if provided
  dynamic "file" {
    for_each = var.mosquitto_config != "" ? [1] : []
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
