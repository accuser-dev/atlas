# Incus VM Module

Provisions Incus VMs for testing Terraform changes in isolated environments before applying them to the production cluster.

## Why VMs Instead of Containers?

1. **Nested Incus support**: VMs can run nested Incus (containers inside VMs) for testing full Atlas deployments
2. **Full kernel isolation**: Safer for testing potentially destructive infrastructure changes
3. **Cloud-init support**: VMs support cloud-init for initial provisioning
4. **Production-like testing**: VMs more closely mirror actual IncusOS cluster behavior

## Usage

This module is **not instantiated in main.tf** - it's a reusable module for ad-hoc testing VMs. Create a separate `.tf` file to use it:

```hcl
# test-vm.tf
module "test_vm" {
  source = "./modules/incus-vm"

  instance_name = "atlas-test01"
  profile_name  = "atlas-test01"
  network_name  = "incusbr0"  # Or use a managed network

  # Resource configuration
  cpu_limit      = "4"
  memory_limit   = "4GB"
  root_disk_size = "50GB"

  # SSH access (optional)
  ssh_public_keys = [
    "ssh-ed25519 AAAA... user@host"
  ]

  # Cloud-init options
  install_opentofu    = true   # Install OpenTofu for testing
  install_incus       = true   # Install nested Incus
  enable_nested_incus = true   # Enable security.nesting
  packages            = ["git", "curl", "jq", "vim"]
}

output "test_vm_ip" {
  value = module.test_vm.ipv4_address
}
```

Then run:

```bash
cd terraform
tofu init
tofu apply -target=module.test_vm
```

## Requirements

| Name | Version |
|------|---------|
| incus | >= 1.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| instance_name | Name of the VM instance | `string` | - | yes |
| profile_name | Name of the Incus profile | `string` | - | yes |
| network_name | Network to attach the VM to | `string` | - | yes |
| image | VM image (must be from images: remote) | `string` | `"images:ubuntu/24.04"` | no |
| cpu_limit | Number of CPU cores | `string` | `"2"` | no |
| memory_limit | Memory limit (e.g., 2GB) | `string` | `"2GB"` | no |
| root_disk_size | Root disk size (e.g., 20GB) | `string` | `"20GB"` | no |
| storage_pool | Storage pool for root disk | `string` | `"local"` | no |
| enable_nested_incus | Enable nested Incus | `bool` | `true` | no |
| ssh_public_keys | SSH public keys for access | `list(string)` | `[]` | no |
| packages | Additional packages to install | `list(string)` | `["git", "curl", "jq"]` | no |
| install_opentofu | Install OpenTofu | `bool` | `true` | no |
| install_incus | Install Incus in the VM | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_name | Name of the VM instance |
| instance_status | Current status of the VM |
| ipv4_address | IPv4 address of the VM |
| ipv6_address | IPv6 address of the VM |
| profile_name | Name of the Incus profile |

## Testing Workflow

### 1. Create a Test VM

```bash
# Create test-vm.tf with your configuration
tofu apply -target=module.test_vm
```

### 2. Access the VM

```bash
# Via Incus console
incus exec atlas-test01 -- bash

# Via SSH (if keys configured)
ssh ubuntu@<ipv4_address>
```

### 3. Wait for Cloud-init

```bash
# Check cloud-init status
cloud-init status --wait

# Or check the completion file
ls -la /var/lib/cloud/instance/boot-finished
```

### 4. Test Atlas Deployment

Inside the VM:

```bash
# Clone the repository
git clone https://github.com/your-org/atlas.git
cd atlas/terraform

# Initialize and apply
tofu init
tofu plan
tofu apply
```

### 5. Cleanup

```bash
tofu destroy -target=module.test_vm
```

## Cloud-init Customization

The module uses cloud-init for initial provisioning. Default behavior:

1. Updates packages
2. Installs specified packages (git, curl, jq by default)
3. Installs OpenTofu (if enabled)
4. Installs and initializes Incus (if enabled)
5. Creates `/var/lib/cloud/instance/boot-finished` when complete

### Custom Packages

```hcl
module "test_vm" {
  # ...
  packages = ["git", "curl", "jq", "vim", "htop", "tmux"]
}
```

### Minimal VM (No Incus/OpenTofu)

```hcl
module "test_vm" {
  # ...
  install_opentofu    = false
  install_incus       = false
  enable_nested_incus = false
}
```

## Notes

- VMs take ~30 seconds to boot plus cloud-init time (~2-5 minutes)
- The `images:ubuntu/24.04` image is recommended for best compatibility
- SSH keys are added to the `ubuntu` user
- Cloud-init logs are at `/var/log/cloud-init.log`
