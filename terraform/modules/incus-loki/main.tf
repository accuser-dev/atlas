locals {
  # Build the configuration map for Incus server logging
  #
  # IMPORTANT: Incus does not persist config values that match their defaults.
  # If we send default values, Incus accepts them but doesn't return them via
  # the API, causing Terraform to report "element has vanished" errors.
  # See: https://github.com/accuser/atlas/issues/135
  #
  # Incus defaults:
  #   - logging.NAME.types = "lifecycle,logging"
  #   - logging.NAME.target.retry = 3

  # Required config keys (always set)
  base_config = {
    "logging.${var.logging_name}.target.type"    = "loki"
    "logging.${var.logging_name}.target.address" = var.loki_address
  }

  # Only include optional config if values differ from Incus defaults
  optional_config = merge(
    # Only set types if different from default "lifecycle,logging"
    var.log_types != "lifecycle,logging" ? {
      "logging.${var.logging_name}.types" = var.log_types
    } : {},
    # Only set retry if different from default 3
    var.retry_count != 3 ? {
      "logging.${var.logging_name}.target.retry" = tostring(var.retry_count)
    } : {},
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
