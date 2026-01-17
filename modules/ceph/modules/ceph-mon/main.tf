# =============================================================================
# Ceph MON Submodule
# =============================================================================
# Deploys a Ceph Monitor daemon in a Debian Trixie container.
# MON maintains cluster state and manages the CRUSH map.
#
# Bootstrap MON: Creates the initial cluster with keyrings
# Joining MON: Joins an existing cluster using keys from bootstrap

locals {
  # Use provided volume name or generate from instance name
  data_volume_name = var.data_volume_name != "" ? var.data_volume_name : "${var.instance_name}-data"

  # Cluster network defaults to public network if not specified
  cluster_network = var.cluster_network != "" ? var.cluster_network : var.public_network

  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    cluster_name        = var.cluster_name
    cluster_fsid        = var.cluster_fsid
    mon_id              = var.mon_id
    mon_port            = var.mon_port
    public_network      = var.public_network
    cluster_network     = local.cluster_network
    is_bootstrap        = var.is_bootstrap
    bootstrap_mon_ip    = var.bootstrap_mon_ip
    mon_initial_members = var.mon_initial_members
    mon_host            = var.mon_host
  })
}

# -----------------------------------------------------------------------------
# Storage Volume for MON Data
# -----------------------------------------------------------------------------

resource "incus_storage_volume" "mon_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = local.data_volume_name
  pool    = var.storage_pool
  project = "default"

  # Pin volume to same node as instance in cluster deployments
  target = var.target_node != "" ? var.target_node : null

  config = {
    size = var.data_volume_size
  }

  content_type = "filesystem"
}

# -----------------------------------------------------------------------------
# Service Profile
# -----------------------------------------------------------------------------

resource "incus_profile" "ceph_mon" {
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

  # MON data volume
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "mon-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.mon_data[0].name
        pool   = var.storage_pool
        path   = "/var/lib/ceph"
      }
    }
  }
}

# -----------------------------------------------------------------------------
# MON Instance
# -----------------------------------------------------------------------------

resource "incus_instance" "ceph_mon" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.ceph_mon.name])

  # Pin to specific cluster node
  target = var.target_node != "" ? var.target_node : null

  config = {
    "security.privileged"  = "false"
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [
    incus_profile.ceph_mon,
    incus_storage_volume.mon_data
  ]
}
