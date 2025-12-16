output "instance_name" {
  description = "Name of the VM instance"
  value       = incus_instance.vm.name
}

output "instance_status" {
  description = "Current status of the VM"
  value       = incus_instance.vm.status
}

output "ipv4_address" {
  description = "IPv4 address of the VM (available after boot)"
  value       = incus_instance.vm.ipv4_address
}

output "ipv6_address" {
  description = "IPv6 address of the VM (available after boot)"
  value       = incus_instance.vm.ipv6_address
}

output "profile_name" {
  description = "Name of the Incus profile created for this VM"
  value       = incus_profile.vm.name
}
