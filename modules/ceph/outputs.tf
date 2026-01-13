# =============================================================================
# Ceph Module Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Cluster Information
# -----------------------------------------------------------------------------

output "cluster_fsid" {
  description = "Ceph cluster FSID"
  value       = local.cluster_fsid
}

output "cluster_name" {
  description = "Ceph cluster name"
  value       = var.cluster_name
}

# -----------------------------------------------------------------------------
# MON Outputs
# -----------------------------------------------------------------------------

output "mon_instances" {
  description = "Map of MON instance names to their details"
  value = {
    for k, v in module.mon : k => {
      instance_name = v.instance_name
      ipv4_address  = v.ipv4_address
      mon_endpoint  = v.mon_endpoint
      is_bootstrap  = v.is_bootstrap
    }
  }
}

output "mon_endpoints" {
  description = "List of MON endpoints (IP:port)"
  value       = [for k, v in module.mon : v.mon_endpoint]
}

output "bootstrap_mon" {
  description = "Bootstrap MON details"
  value = {
    instance_name = module.mon[local.bootstrap_mon_id].instance_name
    ipv4_address  = module.mon[local.bootstrap_mon_id].ipv4_address
    mon_endpoint  = module.mon[local.bootstrap_mon_id].mon_endpoint
  }
}

# -----------------------------------------------------------------------------
# MGR Outputs
# -----------------------------------------------------------------------------

output "mgr_instances" {
  description = "Map of MGR instance names to their details"
  value = {
    for k, v in module.mgr : k => {
      instance_name       = v.instance_name
      ipv4_address        = v.ipv4_address
      dashboard_endpoint  = v.dashboard_endpoint
      prometheus_endpoint = v.prometheus_endpoint
    }
  }
}

output "mgr_prometheus_endpoints" {
  description = "List of MGR Prometheus endpoints"
  value       = [for k, v in module.mgr : v.prometheus_endpoint if v.prometheus_endpoint != null]
}

# -----------------------------------------------------------------------------
# OSD Outputs
# -----------------------------------------------------------------------------

output "osd_instances" {
  description = "Map of OSD instance names to their details"
  value = {
    for k, v in module.osd : k => {
      instance_name    = v.instance_name
      ipv4_address     = v.ipv4_address
      target_node      = v.target_node
      osd_block_device = v.osd_block_device
    }
  }
}

# -----------------------------------------------------------------------------
# RGW Outputs
# -----------------------------------------------------------------------------

output "rgw_instances" {
  description = "Map of RGW instance names to their details"
  value = {
    for k, v in module.rgw : k => {
      instance_name = v.instance_name
      ipv4_address  = v.ipv4_address
      s3_endpoint   = v.s3_endpoint
    }
  }
}

output "s3_endpoints" {
  description = "List of S3 API endpoints"
  value       = [for k, v in module.rgw : v.s3_endpoint]
}

output "primary_s3_endpoint" {
  description = "Primary S3 endpoint (first RGW)"
  value       = length(module.rgw) > 0 ? values(module.rgw)[0].s3_endpoint : null
}
