locals {
  # Build the configuration map for Incus server logging
  # Only include non-empty values to avoid setting unnecessary config
  base_config = {
    "logging.${var.logging_name}.target.type"    = "loki"
    "logging.${var.logging_name}.target.address" = var.loki_address
    "logging.${var.logging_name}.types"          = var.log_types
    "logging.${var.logging_name}.target.retry"   = tostring(var.retry_count)
  }

  optional_config = merge(
    var.labels != "" ? {
      "logging.${var.logging_name}.target.labels" = var.labels
    } : {},
    var.instance_name != "" ? {
      "logging.${var.logging_name}.target.instance" = var.instance_name
    } : {},
    var.lifecycle_types != "" ? {
      "logging.${var.logging_name}.lifecycle.types" = var.lifecycle_types
    } : {},
    var.lifecycle_projects != "" ? {
      "logging.${var.logging_name}.lifecycle.projects" = var.lifecycle_projects
    } : {},
  )

  full_config = merge(local.base_config, local.optional_config)
}

# Configure Incus server to send logs to Loki
resource "incus_server" "logging" {
  config = local.full_config
}
