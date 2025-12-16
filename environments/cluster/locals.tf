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
    node_exporter = {
      cpu    = "1"
      memory = "128MB"
      port   = 9100
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
    promtail = {
      cpu    = "1"
      memory = "256MB"
      port   = 9080
    }
  }
}
