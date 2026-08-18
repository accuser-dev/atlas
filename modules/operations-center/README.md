# Operations Center Module

Provisions an [IncusOS Operations Center](https://docs.futurfusion.io/operations-center/main/) virtual machine — the registration point, update tracker, and inventory for IncusOS servers. Used to provision and manage other IncusOS hosts (e.g. a rebuilt `cluster01`) via generated deployment tokens and pre-seeded install images.

## Why this module looks different from every other Atlas module

Every other service in Atlas is a Debian Trixie **container** configured via cloud-init + Ansible. Operations Center is different on every axis:

- It is an **IncusOS VM**, not a Debian container — IncusOS is only distributed as a bootable OS image.
- It is **immutable and seed-configured**, not Ansible-managed. All configuration happens once, at install time, via a JSON/YAML seed baked into the installer ISO.
- **It cannot run on iapetus's existing IncusOS install.** IncusOS treats `incus`, `migration-manager`, and `operations-center` as mutually-exclusive *primary applications* — only one can own the system (and port 8443) at a time. iapetus already runs `incus` as its primary app, so Operations Center runs as a separate VM guest under it instead.
- **The install is a two-phase, console-watched process** that Terraform cannot express — only the durable artifacts around it (the VM, its profile, and the boot-media attachment) are managed here. See [Install procedure](#install-procedure) below.

## Prerequisites

1. A seeded installer ISO, imported as an Incus storage volume with `content_type = "iso"`. Terraform does not build or own this volume — the provider's `incus_storage_volume` resource cannot reliably import ISO content, and a Terraform-managed `source_file` would require the ISO to exist wherever `tofu apply` runs (which for Atlantis is inside a container, not on iapetus). Build it instead with:

   ```bash
   make operations-center-iso
   ```

   This calls the public `incusos-customizer` service with a seed embedding your Incus client certificate as trusted, then `incus storage volume import ... --type=iso` on iapetus.

2. Your Incus client certificate must be one of the seed's `trusted_client_certificates` — without at least one trusted cert, IncusOS docs warn it becomes "impossible to authenticate to any API endpoint or the web UI post-install."

## Usage

```hcl
module "operations_center01" {
  source = "../../modules/operations-center"

  count = var.enable_operations_center ? 1 : 0

  instance_name = "operations-center01"
  profile_name  = "operations-center"
  profiles      = local.management_profiles

  boot_media_volume = "operations-center01-iso"
  attach_boot_media = var.operations_center_boot_media

  cpu_limit    = local.services.operations_center.cpu
  memory_limit = local.services.operations_center.memory
}
```

## Install procedure

Run once, by hand, after `tofu apply` has created the (stopped) VM with the ISO attached:

1. `incus start iapetus:operations-center01 --console`
2. Wait for: `Custom Secure Boot keys successfully enrolled, rebooting the system now!`
3. Reconnect: `incus console iapetus:operations-center01`
4. Wait for: `IncusOS was successfully installed. Please remove the install media to complete the installation.`
5. Exit the console (`Ctrl+A Q`), then `incus stop iapetus:operations-center01`.
6. Set `attach_boot_media = false` (or `operations_center_boot_media = false` in `terraform.tfvars`) and `tofu apply` — this detaches the ISO device.
7. `incus start iapetus:operations-center01 --console`, wait for `System is ready`. **Note the printed IP address and certificate fingerprint.**
8. Access it:

   ```bash
   mkdir -p ~/.config/operations-center
   cp ~/.config/incus/client.* ~/.config/operations-center/
   operations-center remote add iapetus-oc https://<vm-ip>:8443 --auth-type tls
   operations-center remote switch iapetus-oc
   operations-center provisioning server list   # Operations Center self-registers
   ```

   Or the web UI at `https://<vm-ip>:8443`, authenticating with your Incus client certificate.

To reinstall, set `attach_boot_media = true` again and repeat.

**If a stop/destroy hangs:** `incus stop`/`tofu destroy` wait for the VM to shut itself down gracefully. If it has no working OS to respond to that request (no boot media, a failed install, or firmware with nothing to boot) it can never comply, and the profile's `boot.autorestart = "true"` will fight repeated stop attempts by restarting it. Disable autorestart first, then force-stop:

```bash
incus config set iapetus:operations-center01 boot.autorestart=false
incus stop iapetus:operations-center01 --force
```

**If the VM loses network connectivity after moving it between networks:** IncusOS binds its network config to the NIC's MAC address at install time (there's no explicit network seed here, so this happens implicitly on first boot). Detaching/reattaching the NIC - e.g. moving the instance between networks - makes Incus generate a *new* `volatile.<device>.hwaddr` for the device, which no longer matches what IncusOS persisted. The guest boots with the interface administratively down and the console log shows:

```
ERROR timed out waiting for configured network interfaces, missing interface(s): enp5s0 (<original-mac>)
```

The device name in that error is the NIC device name from the Atlas profile (`mgmt` here), and the MAC in parentheses is the one to restore. Find the NIC device's original MAC from the *first successful* "System is ready" boot (`incus info` on the instance, or check `tofu state show` history / your own notes - Terraform doesn't track this, it's runtime-only Incus state), then:

```bash
incus config set iapetus:operations-center01 boot.autorestart=false
incus stop iapetus:operations-center01 --force
incus config set iapetus:operations-center01 volatile.<device-name>.hwaddr=<original-mac>
incus start iapetus:operations-center01
```

`incus info iapetus:operations-center01` should show the interface `UP` with an IP within ~30s; the console log should show `System is ready` with no `ERROR` line. Since this is Incus-level runtime state (not something Terraform declares), a `tofu plan` afterwards should show no drift - if it does, something else changed too.

**`operations-center01.incus` doesn't resolve, even from another instance on the same network:** every other Atlas service resolves via `<name>.incus` because cloud-init sets each container's hostname to match its Incus instance name, and Incus's per-network dnsmasq registers `<name>.incus` from whatever hostname the DHCP client actually sends - not from the Incus instance name itself. IncusOS has no cloud-init, so it DHCPs under its own machine-id instead. Confirm with:

```bash
incus network list-leases iapetus:management
```

`operations-center01`'s row will show a UUID-looking hostname (its IncusOS machine-id) rather than `operations-center01` - that UUID name *does* resolve (`<uuid>.incus`), just not the instance name. Note this has nothing to do with CoreDNS/the `iapetus.incus` zone (`enable_incus_dns_zone`) - the bare `.incus` domain is resolved directly by the bridge's own dnsmasq (`incus network list-leases`), which containers query directly (check `resolvectl status` / `/etc/resolv.conf` inside the instance) unless something has been explicitly reconfigured to use CoreDNS instead.

The correct fix is setting IncusOS's own hostname so its DHCP client advertises `operations-center01`:

```
config:
  dns:
    hostname: operations-center01
```

via `incus admin os system network edit --force-local`, run *locally* on the instance (console/SSH) - this isn't reachable remotely once Operations Center owns port 8443 as the primary application. Until that's done, use the machine-id hostname from the lease table, or the IP, as a workaround.

## Known limitations

- **OIDC is wired up post-install; OpenFGA is not.** The seed only trusts a client certificate at first boot (see above), to minimize lockout risk. OIDC login via Dex was configured afterwards, live, via `PUT /1.0/system/security` on the Operations Center API (reusing the existing public `incus` Dex client - the OIDC config struct has no client-secret field, so it's PKCE-only) - `oidc.claim` is set to `sub`, not `preferred_username`, since the latter is documented to bounce some providers back to the login screen. This isn't Terraform-managed - it's runtime application config, same category as the IncusOS network/hostname settings above. `dex01`'s redirect URIs (`environments/iapetus/main.tf`) include both a `:8443` (direct, management network) and a no-port (via Cloudflare Tunnel) callback for this reason - whichever way you reach Operations Center needs a matching entry. OpenFGA authorization is still unconfigured.
- **Network reachability for managing cluster01.** This module places the VM on the management network (10.20.0.0/24, NAT'd, iapetus-local). cluster01's nodes will not be able to reach it there without additional routing, an OVN LB VIP, or a proxy device — resolve this before using Operations Center to provision the cluster01 rebuild.

## Requirements

| Name  | Version   |
| ----- | --------- |
| incus | >= 1.0.0  |

## Inputs

| Name                | Description                                              | Type          | Default                    | Required |
| ------------------- | ---------------------------------------------------------| ------------- | --------------------------- | -------- |
| `instance_name`     | Name of the VM instance                                  | `string`      | `"operations-center01"`     | no       |
| `profile_name`      | Name of the Incus profile to create                      | `string`      | `"operations-center"`       | no       |
| `profiles`          | Base/network profiles to compose (e.g. management)       | `list(string)`| `[]`                         | no       |
| `storage_pool`      | Storage pool for the root disk and boot media             | `string`      | `"local"`                   | no       |
| `target_node`       | Target cluster node (clustered deployments)               | `string`      | `null`                      | no       |
| `cpu_limit`         | Number of CPU cores                                       | `string`      | `"2"`                        | no       |
| `memory_limit`      | Memory limit                                               | `string`      | `"4GB"`                      | no       |
| `root_disk_size`    | Root disk size (minimum 10GB)                              | `string`      | `"50GB"`                     | no       |
| `attach_boot_media` | Attach the installer ISO (true to install, false after)   | `bool`        | `true`                       | no       |
| `boot_media_volume` | Name of the pre-imported ISO volume                        | `string`      | `"operations-center01-iso"` | no       |

## Outputs

| Name              | Description                                    |
| ----------------- | ----------------------------------------------- |
| `instance_name`   | Name of the VM instance                          |
| `instance_status` | Current status of the VM                         |
| `ipv4_address`    | IPv4 address of the VM                           |
| `profile_name`    | Name of the created profile                      |
| `web_endpoint`    | `https://<ip>:8443` UI/API endpoint              |
| `instance_info`   | `{ name, ipv4_address }` for discovery purposes  |

## References

- [Operations Center documentation](https://docs.futurfusion.io/operations-center/main/)
- [Operations Center GitHub](https://github.com/FuturFusion/operations-center)
- [IncusOS Operations Center application reference](https://linuxcontainers.org/incus-os/docs/main/reference/applications/operations-center/)
- [IncusOS seed reference](https://linuxcontainers.org/incus-os/docs/main/reference/seed/)
