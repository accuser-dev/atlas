# =============================================================================
# step-ca Module
# =============================================================================
# Internal ACME Certificate Authority for automated TLS certificate management
# Uses Debian Trixie system container with cloud-init and systemd for configuration

locals {
  # Build DNS names list - always include instance name and localhost
  default_dns_names = "${var.instance_name}.incus,localhost"
  ca_dns_names      = var.ca_dns_names != "" ? "${var.ca_dns_names},${local.default_dns_names}" : local.default_dns_names

  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    step_version  = var.step_version
    ca_name       = var.ca_name
    ca_dns_names  = local.ca_dns_names
    acme_port     = var.acme_port
    cert_duration = var.cert_duration
  })
}

# Storage volume for CA data (private keys, config, certificate database)
resource "incus_storage_volume" "step_ca_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = var.data_volume_name
  pool    = var.storage_pool
  project = "default"

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
# Contains resource limits, root disk with size limit, and service-specific devices
# Network is provided by profiles passed via var.profiles
resource "incus_profile" "step_ca" {
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
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.step_ca.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [
    incus_profile.step_ca,
    incus_storage_volume.step_ca_data
  ]
}
