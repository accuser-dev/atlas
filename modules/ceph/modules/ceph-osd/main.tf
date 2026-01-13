# =============================================================================
# Ceph OSD Submodule
# =============================================================================
# Deploys a Ceph OSD daemon in a Debian Trixie container.
# OSD manages data storage on a block device.
#
# IMPORTANT: This container requires privileged mode for block device access.
# The block device is passed through from the host using unix-block device type.

locals {
  # Cluster network defaults to public network if not specified
  cluster_network = var.cluster_network != "" ? var.cluster_network : var.public_network

  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    cluster_name        = var.cluster_name
    cluster_fsid        = var.cluster_fsid
    mon_initial_members = var.mon_initial_members
    mon_host            = var.mon_host
    public_network      = var.public_network
    cluster_network     = local.cluster_network
    osd_objectstore     = var.osd_objectstore
  })
}

# -----------------------------------------------------------------------------
# Service Profile
# -----------------------------------------------------------------------------

resource "incus_profile" "ceph_osd" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
  }

  # Root disk
  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
      size = var.root_disk_size
    }
  }

  # Storage network NIC
  device {
    name = "eth0"
    type = "nic"
    properties = merge(
      { network = var.storage_network_name },
      var.static_ip != null && var.static_ip != "" ? { "ipv4.address" = var.static_ip } : {}
    )
  }

  # OSD block device passthrough
  device {
    name = "osd-block"
    type = "unix-block"
    properties = {
      source   = var.osd_block_device
      path     = "/dev/osd-block"
      required = "true"
    }
  }
}

# -----------------------------------------------------------------------------
# OSD Instance
# -----------------------------------------------------------------------------

resource "incus_instance" "ceph_osd" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.ceph_osd.name])

  # Pin to specific cluster node (required for OSD)
  target = var.target_node

  config = {
    # Privileged mode required for block device operations
    "security.privileged"  = "true"
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [incus_profile.ceph_osd]
}
