output "logging_name" {
  description = "Name of the logging configuration"
  value       = var.logging_name
}

output "loki_address" {
  description = "Address of the Loki server being used"
  value       = var.loki_address
}

output "log_types" {
  description = "Event types being sent to Loki"
  value       = var.log_types
}

output "config_keys" {
  description = "List of Incus server config keys that were set"
  value       = keys(local.full_config)
}
