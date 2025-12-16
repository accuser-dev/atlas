# =============================================================================
# Incus VM Module
# =============================================================================
# Provisions Incus VMs for testing Terraform changes in isolated environments.
# VMs support cloud-init for initial provisioning and nested Incus for
# testing full Atlas deployments.

# VM-specific profile with resource limits and optional nested virtualization
resource "incus_profile" "vm" {
  name = var.profile_name

  config = merge(
    {
      "limits.cpu"            = var.cpu_limit
      "limits.memory"         = var.memory_limit
      "limits.memory.enforce" = "hard"
      "boot.autorestart"      = "true"
    },
    var.enable_nested_incus ? {
      "security.nesting" = "true"
    } : {}
  )

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
      size = var.root_disk_size
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.network_name
    }
  }
}

# VM instance with cloud-init for initial provisioning
resource "incus_instance" "vm" {
  name     = var.instance_name
  image    = var.image
  type     = "virtual-machine"
  profiles = [incus_profile.vm.name]

  config = {
    "cloud-init.user-data" = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      ssh_public_keys  = var.ssh_public_keys
      packages         = var.packages
      install_opentofu = var.install_opentofu
      install_incus    = var.install_incus
      hostname         = var.instance_name
    })
  }
}
