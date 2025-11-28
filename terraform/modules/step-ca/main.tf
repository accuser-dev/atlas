# step-ca - Internal ACME Certificate Authority
# Provides automated TLS certificate management for internal services

locals {
  # Build DNS names list - always include instance name and localhost
  default_dns_names = "${var.instance_name}.incus,localhost"
  ca_dns_names      = var.ca_dns_names != "" ? "${var.ca_dns_names},${local.default_dns_names}" : local.default_dns_names
}

# Storage volume for CA data (private keys, config, certificate database)
resource "incus_storage_volume" "step_ca_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = merge(
    {
      size = var.data_volume_size
      # Set initial ownership for step user (UID 1000) to allow writes from non-root container
      # Requires Incus 6.8+ (https://linuxcontainers.org/incus/news/2024_12_13_07_12.html)
      "initial.uid"  = "1000"
      "initial.gid"  = "1000"
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
# Contains only resource limits and service-specific devices (data volume)
# Base infrastructure (root disk, network) is provided by profiles passed via var.profiles
resource "incus_profile" "step_ca" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
  }

  # Mount persistent volume for CA data
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "step-ca-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.step_ca_data[0].name
        pool   = var.storage_pool
        path   = "/home/step"
      }
    }
  }

  depends_on = [
    incus_storage_volume.step_ca_data
  ]
}

# step-ca container
resource "incus_instance" "step_ca" {
  name  = var.instance_name
  image = var.image
  type  = "container"

  profiles = concat(var.profiles, [incus_profile.step_ca.name])

  config = {
    # Environment variables for CA configuration
    "environment.STEPCA_NAME"          = var.ca_name
    "environment.STEPCA_DNS"           = local.ca_dns_names
    "environment.STEPCA_ADDRESS"       = ":${var.acme_port}"
    "environment.STEPCA_CERT_DURATION" = var.cert_duration
  }

  depends_on = [
    incus_profile.step_ca,
    incus_storage_volume.step_ca_data
  ]
}
