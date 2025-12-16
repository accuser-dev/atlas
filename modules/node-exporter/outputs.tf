output "instance_name" {
  description = "Name of the Node Exporter instance"
  value       = incus_instance.node_exporter.name
}

output "profile_name" {
  description = "Name of the Node Exporter profile"
  value       = incus_profile.node_exporter.name
}

output "node_exporter_endpoint" {
  description = "Node Exporter metrics endpoint URL"
  value       = "http://${var.instance_name}.incus:${var.node_exporter_port}"
}
