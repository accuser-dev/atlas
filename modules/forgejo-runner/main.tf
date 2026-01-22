# =============================================================================
# Forgejo Runner Module
# =============================================================================
# Creates a minimal container for Forgejo Actions runner.
# Configuration is handled by Ansible - this module only manages:
#   - Container lifecycle
#   - Incus profile (CPU/memory limits)
#   - Storage volume
#   - Network attachment
#
# Cloud-init installs only Python3 (required for Ansible connection).

locals {
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    # Minimal cloud-init - Ansible handles the rest
  })
}

# =============================================================================
# Storage Volume
# =============================================================================

resource "incus_storage_volume" "forgejo_runner_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = var.data_volume_name
  pool    = var.storage_pool
  project = "default"
  target  = var.target_node

  config = {
    size = var.data_volume_size
    # Runner runs as forgejo-runner user (UID/GID set by Ansible)
    "initial.uid"  = "1100"
    "initial.gid"  = "1100"
    "initial.mode" = "0755"
  }

  content_type = "filesystem"
}

# =============================================================================
# Profile
# =============================================================================

resource "incus_profile" "forgejo_runner" {
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

  # Data volume mount (for work directory and cache)
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "runner-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.forgejo_runner_data[0].name
        pool   = var.storage_pool
        path   = "/opt/forgejo-runner"
      }
    }
  }
}

# =============================================================================
# Container Instance
# =============================================================================

resource "incus_instance" "forgejo_runner" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.forgejo_runner.name])
  target   = var.target_node

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [
    incus_profile.forgejo_runner,
    incus_storage_volume.forgejo_runner_data
  ]
}
