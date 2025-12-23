# Storage volume for Atlantis data (plans cache, locks, working directories)
resource "incus_storage_volume" "atlantis_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = var.data_volume_name
  pool    = var.storage_pool
  project = "default"

  config = merge(
    {
      size = var.data_volume_size
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
# Contains resource limits and service-specific devices (root disk with size limit, data volume)
# Base infrastructure (network) is provided by profiles passed via var.profiles
resource "incus_profile" "atlantis" {
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

  # Data volume for persistent Atlantis data
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "atlantis-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.atlantis_data[0].name
        pool   = var.storage_pool
        path   = "/atlantis-data"
      }
    }
  }

  depends_on = [
    incus_storage_volume.atlantis_data
  ]
}

# Atlantis container instance
resource "incus_instance" "atlantis" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.atlantis.name])

  config = {
    # GitHub configuration
    "environment.ATLANTIS_GH_USER"           = var.github_user
    "environment.ATLANTIS_GH_TOKEN"          = var.github_token
    "environment.ATLANTIS_GH_WEBHOOK_SECRET" = var.github_webhook_secret
    "environment.ATLANTIS_REPO_ALLOWLIST"    = join(",", var.repo_allowlist)

    # Atlantis server configuration
    "environment.ATLANTIS_ATLANTIS_URL" = var.atlantis_url
    "environment.ATLANTIS_PORT"         = var.atlantis_port
    "environment.ATLANTIS_DATA_DIR"     = "/atlantis-data"

    # Use OpenTofu instead of Terraform
    "environment.ATLANTIS_AUTOPLAN_FILE_LIST" = "**/*.tf,**/*.tfvars,**/*.tftpl"
  }

  # Inject server-side repo configuration if enabled
  dynamic "file" {
    for_each = var.enable_repo_config && var.repo_config != "" ? [1] : []
    content {
      content     = var.repo_config
      target_path = "/atlantis-data/repos.yaml"
      mode        = "0644"
    }
  }
}
