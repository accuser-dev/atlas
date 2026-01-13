# =============================================================================
# Centralized Service Configuration for Cluster Environment
# =============================================================================

locals {
  # Service resource limits
  # These match the iapetus environment where applicable
  services = {
    prometheus = {
      cpu    = "2"
      memory = "2GB"
      port   = 9090
    }
    alertmanager = {
      cpu    = "1"
      memory = "256MB"
      port   = 9093
    }
    mosquitto = {
      cpu    = "1"
      memory = "256MB"
      port   = 1883
    }
    coredns = {
      cpu    = "1"
      memory = "128MB"
      port   = 53
    }
    alloy = {
      cpu    = "1"
      memory = "256MB"
      port   = 12345
    }
    ceph_mon = {
      cpu    = "2"
      memory = "2GB"
    }
    ceph_mgr = {
      cpu    = "2"
      memory = "1GB"
    }
    ceph_osd = {
      cpu    = "4"
      memory = "4GB"
    }
    ceph_rgw = {
      cpu    = "2"
      memory = "2GB"
    }
  }
}
