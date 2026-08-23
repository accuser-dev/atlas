# =============================================================================
# Operations Center Module
# =============================================================================
# Provisions an IncusOS virtual machine running the operations-center primary
# application. Unlike every other Atlas service, this is not a Debian Trixie
# container configured via cloud-init/Ansible - it is an immutable IncusOS
# image installed from a seeded ISO (built outside Terraform, see the
# `operations-center-iso` Makefile target) and configured entirely via its
# install-time seed.
#
# IncusOS treats `incus`, `migration-manager`, and `operations-center` as
# mutually-exclusive primary applications, so this cannot run on iapetus's
# existing IncusOS install - it runs as a VM guest under it instead.
#
# The ISO install is a two-phase, console-watched process that Terraform
# cannot express (see modules/operations-center/README.md). `attach_boot_media`
# is the lever for that: true to boot the installer, false afterwards to
# detach it so the VM boots from its own disk.

resource "incus_profile" "operations_center" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
    "boot.autorestart"      = "true"
  }

  # Root disk with size limit
  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
      size = var.root_disk_size
    }
  }
}

resource "incus_instance" "operations_center" {
  name     = var.instance_name
  type     = "virtual-machine"
  profiles = concat(var.profiles, [incus_profile.operations_center.name])
  target   = var.target_node

  # No image: IncusOS is installed from the seeded ISO attached below, not
  # from an `images:` source. The provider requires running=false at create
  # time for an imageless VM; the install ceremony (README) starts it
  # manually via `incus start ... --console`. Once running, this no longer
  # reflects reality (IncusOS, not Terraform, owns the VM's power state from
  # here on) - `running` is in ignore_changes below so a routine `tofu apply`
  # (e.g. Atlantis auto-apply on an unrelated PR) doesn't stop it.
  running = false

  config = {
    "security.secureboot" = "false"
  }

  # Virtual TPM required by IncusOS's secure boot key enrollment
  device {
    name       = "vtpm"
    type       = "tpm"
    properties = {}
  }

  # Pin NIC hwaddrs so IncusOS's first-boot network binding survives a
  # detach/reattach - see var.network_interfaces and README "Known
  # limitations" for why an unpinned MAC breaks networking. This device
  # fully replaces (not merges with) the same-named device inherited from
  # `profiles`, so `network` must be re-declared here alongside `hwaddr`.
  dynamic "device" {
    for_each = { for iface in var.network_interfaces : iface.device => iface }
    content {
      name = device.key
      type = "nic"
      properties = {
        network = device.value.network
        hwaddr  = device.value.hwaddr
      }
    }
  }

  # Seeded installer ISO - detach (attach_boot_media = false) once IncusOS
  # reports "successfully installed" so the VM boots from its own disk.
  dynamic "device" {
    for_each = var.attach_boot_media ? [1] : []
    content {
      name = "boot-media"
      type = "disk"
      properties = {
        pool            = var.storage_pool
        source          = var.boot_media_volume
        "boot.priority" = "10"
      }
    }
  }

  # Optional extra seed volume (a small ISO/FAT volume labeled SEED_DATA,
  # containing per-category seed JSON files like security.json) - a
  # user-provided seed source IncusOS scans for by that exact volume label
  # (incus-osd/internal/seed/seed.go's getSeedPath()), independent of and
  # merged on top of the seed baked into boot-media by the customizer
  # service. Exists because that service's own request schema
  # (ImagesPostSeeds) doesn't accept every seed category the general
  # IncusOS seed format supports - e.g. `security.custom_ca_certs` - so
  # anything unsupported there has to arrive this way instead. Left
  # permanently attached (no boot priority): IncusOS re-reads it on every
  # boot, not just install, which is what we want for this content.
  dynamic "device" {
    for_each = var.extra_seed_volume != "" ? [1] : []
    content {
      name = "extra-seed"
      type = "disk"
      properties = {
        pool   = var.storage_pool
        source = var.extra_seed_volume
      }
    }
  }

  depends_on = [
    incus_profile.operations_center,
  ]

  # `running` only reflects the create-time requirement for an imageless VM;
  # afterwards its actual power state is not something this module should
  # fight with the operator/IncusOS over. See comment on `running` above.
  lifecycle {
    ignore_changes = [running]
  }
}
