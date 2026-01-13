# =============================================================================
# Ceph Module
# =============================================================================
# Deploys a complete Ceph cluster using submodules for each daemon type.
#
# Architecture:
#   - MON: Cluster monitors (minimum 3 for quorum)
#   - MGR: Manager daemons (dashboard, prometheus metrics)
#   - OSD: Object Storage Daemons (one per block device)
#   - RGW: RADOS Gateway (S3-compatible API)
#
# Deployment order:
#   1. Bootstrap MON (creates cluster, generates keys)
#   2. Additional MONs (join cluster)
#   3. MGR daemons
#   4. OSD daemons
#   5. RGW daemons

# -----------------------------------------------------------------------------
# Cluster FSID
# -----------------------------------------------------------------------------
# Generate a random UUID if not provided

resource "random_uuid" "cluster_fsid" {
  count = var.cluster_fsid == "" ? 1 : 0
}

locals {
  cluster_fsid    = var.cluster_fsid != "" ? var.cluster_fsid : random_uuid.cluster_fsid[0].result
  cluster_network = var.cluster_network != "" ? var.cluster_network : var.public_network

  # Find bootstrap MON
  bootstrap_mon_id = [for k, v in var.mons : k if v.is_bootstrap][0]
  bootstrap_mon    = var.mons[local.bootstrap_mon_id]

  # Build MON lists for ceph.conf
  mon_ids = join(",", keys(var.mons))

  # MON hosts - use static IPs if provided, otherwise leave empty (will be populated dynamically)
  # Filter out empty strings to avoid ",," in the output
  mon_host_list = [for k, v in var.mons : v.static_ip if v.static_ip != null && v.static_ip != ""]
  mon_hosts     = length(local.mon_host_list) > 0 ? join(",", local.mon_host_list) : ""

  # Bootstrap MON IP - use static if provided, otherwise empty (will use hostname resolution)
  bootstrap_mon_ip = local.bootstrap_mon.static_ip != null ? local.bootstrap_mon.static_ip : ""
}

# -----------------------------------------------------------------------------
# MON Daemons
# -----------------------------------------------------------------------------

module "mon" {
  source   = "./modules/ceph-mon"
  for_each = var.mons

  instance_name = "ceph-mon-${each.key}"
  profile_name  = "ceph-mon-${each.key}"
  image         = var.image
  profiles      = var.profiles
  target_node   = each.value.target_node

  cpu_limit      = var.mon_cpu_limit
  memory_limit   = var.mon_memory_limit
  storage_pool   = var.storage_pool
  root_disk_size = "5GB"

  enable_data_persistence = true
  data_volume_name        = "ceph-mon-${each.key}-data"
  data_volume_size        = var.mon_data_volume_size

  cluster_name   = var.cluster_name
  cluster_fsid   = local.cluster_fsid
  mon_id         = each.key
  public_network = var.public_network

  is_bootstrap        = each.value.is_bootstrap
  bootstrap_mon_ip    = local.bootstrap_mon_ip
  mon_initial_members = local.mon_ids
  mon_host            = local.mon_hosts

  storage_network_name = var.storage_network_name
  static_ip            = each.value.static_ip
}

# -----------------------------------------------------------------------------
# MGR Daemons
# -----------------------------------------------------------------------------

module "mgr" {
  source   = "./modules/ceph-mgr"
  for_each = var.mgrs

  instance_name = "ceph-mgr-${each.key}"
  profile_name  = "ceph-mgr-${each.key}"
  image         = var.image
  profiles      = var.profiles
  target_node   = each.value.target_node

  cpu_limit      = var.mgr_cpu_limit
  memory_limit   = var.mgr_memory_limit
  storage_pool   = var.storage_pool
  root_disk_size = "5GB"

  cluster_name        = var.cluster_name
  cluster_fsid        = local.cluster_fsid
  mgr_id              = each.key
  mon_initial_members = local.mon_ids
  mon_host            = local.mon_hosts
  public_network      = var.public_network

  enable_dashboard  = var.enable_mgr_dashboard
  enable_prometheus = var.enable_mgr_prometheus

  storage_network_name = var.storage_network_name
  static_ip            = each.value.static_ip

  depends_on = [module.mon]
}

# -----------------------------------------------------------------------------
# OSD Daemons
# -----------------------------------------------------------------------------

module "osd" {
  source   = "./modules/ceph-osd"
  for_each = var.osds

  instance_name = "ceph-osd-${each.key}"
  profile_name  = "ceph-osd-${each.key}"
  image         = var.image
  profiles      = var.profiles
  target_node   = each.value.target_node

  cpu_limit      = var.osd_cpu_limit
  memory_limit   = var.osd_memory_limit
  storage_pool   = var.storage_pool
  root_disk_size = "10GB"

  osd_block_device = each.value.osd_block_device

  cluster_name        = var.cluster_name
  cluster_fsid        = local.cluster_fsid
  mon_initial_members = local.mon_ids
  mon_host            = local.mon_hosts
  public_network      = var.public_network
  cluster_network     = local.cluster_network

  storage_network_name = var.storage_network_name
  static_ip            = each.value.static_ip

  depends_on = [module.mon]
}

# -----------------------------------------------------------------------------
# RGW Daemons
# -----------------------------------------------------------------------------

module "rgw" {
  source   = "./modules/ceph-rgw"
  for_each = var.rgws

  instance_name = "ceph-rgw-${each.key}"
  profile_name  = "ceph-rgw-${each.key}"
  image         = var.image
  profiles      = var.profiles
  target_node   = each.value.target_node

  cpu_limit      = var.rgw_cpu_limit
  memory_limit   = var.rgw_memory_limit
  storage_pool   = var.storage_pool
  root_disk_size = "5GB"

  cluster_name        = var.cluster_name
  cluster_fsid        = local.cluster_fsid
  rgw_id              = each.key
  mon_initial_members = local.mon_ids
  mon_host            = local.mon_hosts
  public_network      = var.public_network
  rgw_port            = var.rgw_port

  storage_network_name = var.storage_network_name
  static_ip            = each.value.static_ip

  depends_on = [module.mon, module.osd]
}
