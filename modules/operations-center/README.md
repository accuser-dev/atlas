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

3. `environments/iapetus/operations-center-seed.json` — the single source of truth for values needed by **both** Terraform (pinned NIC hwaddrs) and `make operations-center-iso` (the install seed), so the two can never drift apart. See [Seed-based configuration](#seed-based-configuration) below.

## Usage

```hcl
module "operations_center01" {
  source = "../../modules/operations-center"

  count = var.enable_operations_center ? 1 : 0

  instance_name = "operations-center01"
  profile_name  = "operations-center"
  profiles      = local.management_and_production_profiles

  # Pins NIC hwaddrs from operations-center-seed.json so Incus never
  # regenerates volatile.<device>.hwaddr — see Seed-based configuration.
  network_interfaces = local.operations_center_network_interfaces

  boot_media_volume = "operations-center01-iso"
  attach_boot_media = var.operations_center_boot_media

  cpu_limit    = local.services.operations_center.cpu
  memory_limit = local.services.operations_center.memory
}
```

## Seed-based configuration

`make operations-center-iso` no longer builds a minimal seed. It reads `environments/iapetus/operations-center-seed.json` and, where available, live Terraform/OpenFGA state, to seed:

- **Hostname** (`network.dns.hostname`) — so the DHCP client advertises `operations-center01` instead of IncusOS's machine-id UUID, which is what the bridge's dnsmasq registers as `<name>.incus`.
- **Both NICs** (`network.interfaces`), addressed by the hwaddr pinned in Terraform via `network_interfaces` — so the second (production) NIC comes up on first boot instead of staying `State: DOWN`. The production interface is explicitly given the `management` role and the mgmt interface none; IncusOS auto-assigns `management`+`cluster` to every routable interface when no interface has any role configured at all, and `GetInterfaceAddressByRole` (which drives what Operations Center advertises for registration — see below) has no tiebreaker between two candidates beyond Go's randomized map iteration. Leaving both interfaces roleless would make the advertised address a coin flip per boot between the NAT'd `10.20.0.0/24` management address and the LAN-routable production one — cluster01 can only reach the latter.
- **OIDC** (`operations-center.preseed.system_security.oidc`) — reusing the public PKCE `incus` Dex client, `claim: sub`. Requires `dex01` already applied (reads `tofu output dex_issuer_url`); skipped with a warning otherwise.
- **OpenFGA** (`operations-center.preseed.system_security.openfga`) — resolves (or creates) a store named `operations-center` on `openfga01` and seeds its ID + API token. Requires `openfga01` applied *and configured* (`make configure-openfga-full`) and `OPENFGA_PRESHARED_KEY` passed to the Makefile target; skipped with a warning otherwise. Operations Center uploads its own built-in authorization model to the store on first connect — nothing else to push.

**This is the rebuild path, not the update path.** The seed applies once, at first boot. It has no effect on an already-installed instance — changing the JSON and rebuilding the ISO means a full reinstall (below). The manual procedures later in this doc remain how you fix or reconfigure a running instance.

**Security note:** seeding OpenFGA means `OPENFGA_PRESHARED_KEY` is sent to the third-party `incusos-customizer.linuxcontainers.org` service (which builds the ISO) and ends up stored, unencrypted, in the resulting ISO volume on iapetus. This is the same trust boundary the seed's `trusted_client_certificates` already crosses. See `SECURITY.md`.

### From-scratch rebuild ordering

`openfga01` must be running *with the preshared key configured* (an Ansible step, not part of `make apply`) before the OpenFGA store can be resolved:

```bash
make apply                        # operations_center disabled — brings up dex01, openfga01, coredns01, ...
make configure-openfga-full       # OPENFGA_PRESHARED_KEYS=<key> — required before the store lookup works
make configure-dex-full           # GitHub credentials for Dex, if not already configured
OPENFGA_PRESHARED_KEY=<key> make operations-center-iso ENV=iapetus
# set enable_operations_center = true, operations_center_boot_media = true
make apply
# console install ceremony, below
# set operations_center_boot_media = false; make apply
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

To reinstall onto a **blank disk** (a genuine from-scratch rebuild, e.g. after `tofu destroy` recreated the instance), set `attach_boot_media = true` again and repeat — the seed's `install.force_install` stays `false`, which is correct when there's no existing install to overwrite.

Reinstalling **in place**, over an already-installed disk (e.g. re-running this against the current `operations-center01` to pick up new seed values), is a different, mostly-manual path: IncusOS refuses to overwrite an existing install of the same version without an install-specific confirmation code, derived from the running system's machine-id and only knowable by watching the console — `force_install: false` in the seed will make it stop and print that requirement rather than proceed. There is no way to pre-compute this from the Makefile. Either destroy the instance first (`tofu destroy -target=module.operations_center01`, wiping the disk, then re-apply) so there's nothing to detect, or watch the console for the refusal message and its confirmation code, and be prepared to intervene by hand.

**If a stop/destroy hangs:** `incus stop`/`tofu destroy` wait for the VM to shut itself down gracefully. If it has no working OS to respond to that request (no boot media, a failed install, or firmware with nothing to boot) it can never comply, and the profile's `boot.autorestart = "true"` will fight repeated stop attempts by restarting it. Disable autorestart first, then force-stop:

```bash
incus config set iapetus:operations-center01 boot.autorestart=false
incus stop iapetus:operations-center01 --force
```

**If the VM loses network connectivity after moving it between networks:** IncusOS binds its network config to each NIC's MAC address at first boot. On a fresh install seeded per [Seed-based configuration](#seed-based-configuration), that MAC is the one pinned by `network_interfaces` in Terraform, which Incus never regenerates — so this failure mode shouldn't recur for new builds. It's still possible on an instance whose devices predate the pin (or where `network_interfaces` doesn't cover a given NIC): detaching/reattaching the NIC — e.g. moving the instance between networks — makes Incus generate a *new* `volatile.<device>.hwaddr` for the device, which no longer matches what IncusOS persisted. The guest boots with the interface administratively down and the console log shows:

```plaintext
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

**`operations-center01.incus` doesn't resolve, even from another instance on the same network:** every other Atlas service resolves via `<name>.incus` because cloud-init sets each container's hostname to match its Incus instance name, and Incus's per-network dnsmasq registers `<name>.incus` from whatever hostname the DHCP client actually sends - not from the Incus instance name itself. IncusOS has no cloud-init, so without a seeded hostname it DHCPs under its own machine-id instead. [Seed-based configuration](#seed-based-configuration) sets `network.dns.hostname` for this on new builds; this remains the fix for an already-installed instance. Confirm with:

```bash
incus network list-leases iapetus:management
```

`operations-center01`'s row will show a UUID-looking hostname (its IncusOS machine-id) rather than `operations-center01` - that UUID name *does* resolve (`<uuid>.incus`), just not the instance name. Note this has nothing to do with CoreDNS/the `iapetus.incus` zone (`enable_incus_dns_zone`) - the bare `.incus` domain is resolved directly by the bridge's own dnsmasq (`incus network list-leases`), which containers query directly (check `resolvectl status` / `/etc/resolv.conf` inside the instance) unless something has been explicitly reconfigured to use CoreDNS instead.

The correct fix is setting IncusOS's own hostname so its DHCP client advertises `operations-center01`:

```yaml
config:
  dns:
    hostname: operations-center01
```

via `incus admin os system network edit --force-local`, run *locally* on the instance (console/SSH) - this isn't reachable remotely once Operations Center owns port 8443 as the primary application. Until that's done, use the machine-id hostname from the lease table, or the IP, as a workaround.

## Known limitations

- **On the currently-installed `operations-center01`, OIDC/OpenFGA are still runtime-only.** [Seed-based configuration](#seed-based-configuration) covers a *new* build; the live instance predates it and was configured live, via `PUT /1.0/system/security` on the Operations Center API — reusing the existing public `incus` Dex client (the OIDC config struct has no client-secret field, so it's PKCE-only), `oidc.claim` set to `sub` rather than `preferred_username` since the latter is documented to bounce some providers back to the login screen. `dex01`'s redirect URIs (`environments/iapetus/main.tf`) include both a `:8443` (direct, management network) and a no-port (via Cloudflare Tunnel) callback for this reason — whichever way you reach Operations Center needs a matching entry. Reconfiguring OIDC/OpenFGA on the live instance without a reinstall still means repeating this `PUT` by hand; the seed only takes effect at first boot.
- **Network reachability for managing cluster01.** `environments/iapetus/main.tf` dual-homes this VM on both the management network (10.20.0.0/24, NAT'd, iapetus-local) and the production network (LAN-attached via `eno2` in physical mode), so it should be directly reachable from cluster01's nodes without extra routing, an OVN LB VIP, or a proxy device — as long as cluster01 sits on the same LAN segment as `eno2`.

  On a fresh install with both NICs present in the profile from the start and seeded via `network.interfaces` ([Seed-based configuration](#seed-based-configuration)), both should come up DHCP-configured at first boot. On the currently-installed instance, the production NIC was added by a live profile change *after* install and does not come up on its own — confirmed, not just suspected: `incus info` showed it `State: DOWN`, no address, even after the profile change applied and the instance kept running. Same root cause as the hostname gotcha above: no cloud-init, so nothing tells IncusOS to notice and DHCP-configure an interface it's never seen before. It has to be activated locally, the same way as the hostname fix:

  ```bash
  incus admin os system network show --force-local   # see current config as a template
  incus admin os system network edit --force-local    # add the new interface with DHCP enabled
  ```

  Run this from console/SSH on the instance itself (not reachable remotely once Operations Center owns port 8443). The exact YAML for adding a second interface hasn't been documented here yet - use the existing (working) interface's entry from `show` as the template.

## Requirements

| Name  | Version   |
| ----- | --------- |
| incus | >= 1.0.0  |

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| `instance_name` | Name of the VM instance | `string` | `"operations-center01"` | no |
| `profile_name` | Name of the Incus profile to create | `string` | `"operations-center"` | no |
| `profiles` | Base/network profiles to compose (e.g. management) | `list(string)` | `[]` | no |
| `network_interfaces` | Per-NIC hwaddr pins overriding devices inherited from `profiles` — see [Seed-based configuration](#seed-based-configuration) | `list(object({device, network, hwaddr}))` | `[]` | no |
| `storage_pool` | Storage pool for the root disk and boot media | `string` | `"local"` | no |
| `target_node` | Target cluster node (clustered deployments) | `string` | `null` | no |
| `cpu_limit` | Number of CPU cores | `string` | `"2"` | no |
| `memory_limit` | Memory limit | `string` | `"4GB"` | no |
| `root_disk_size` | Root disk size, binary units (minimum 50GiB) | `string` | `"55GiB"` | no |
| `attach_boot_media` | Attach the installer ISO (true to install, false after) | `bool` | `true` | no |
| `boot_media_volume` | Name of the pre-imported ISO volume | `string` | `"operations-center01-iso"` | no |

## Outputs

| Name | Description |
| --- | --- |
| `instance_name` | Name of the VM instance |
| `instance_status` | Current status of the VM |
| `ipv4_address` | IPv4 address of the VM |
| `profile_name` | Name of the created profile |
| `web_endpoint` | `https://<ip>:8443` UI/API endpoint |
| `instance_info` | `{ name, ipv4_address }` for discovery purposes |

## References

- [Operations Center documentation](https://docs.futurfusion.io/operations-center/main/)
- [Operations Center GitHub](https://github.com/FuturFusion/operations-center)
- [IncusOS Operations Center application reference](https://linuxcontainers.org/incus-os/docs/main/reference/applications/operations-center/)
- [IncusOS seed reference](https://linuxcontainers.org/incus-os/docs/main/reference/seed/)
