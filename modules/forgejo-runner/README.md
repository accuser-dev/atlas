# Forgejo Runner Module

Creates a minimal Incus container for Forgejo Actions runner. This module follows the **hybrid Terraform + Ansible pattern** where:

- **Terraform** manages container lifecycle (creation, profiles, storage, networking)
- **Ansible** handles configuration management (binary installation, registration, systemd service)

## Usage

```hcl
module "forgejo_runner01" {
  source = "../../modules/forgejo-runner"

  instance_name = "forgejo-runner01"
  profile_name  = "forgejo-runner"

  profiles = [
    module.base.container_base_profile.name,
    module.base.production_network_profile.name,
  ]

  forgejo_url   = "https://git.example.com"
  runner_labels = "debian-trixie:host,linux_amd64:host"

  enable_data_persistence = true
  data_volume_name        = "forgejo-runner01-data"
  data_volume_size        = "20GB"

  target_node = "node01"

  cpu_limit    = "2"
  memory_limit = "2GB"
}
```

## Workflow

1. **Deploy container with Terraform:**
   ```bash
   make apply ENV=cluster01
   ```

2. **Install Ansible requirements (first time only):**
   ```bash
   make ansible-setup
   ```

3. **Get registration token from Forgejo:**
   - Go to Forgejo Admin > Actions > Runners
   - Click "Create new runner"
   - Copy the registration token

4. **Configure and register the runner:**
   ```bash
   FORGEJO_RUNNER_TOKEN=<token> make configure-runner-register ENV=cluster01
   ```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `instance_name` | Container instance name | `string` | `"forgejo-runner01"` |
| `profile_name` | Incus profile name | `string` | `"forgejo-runner"` |
| `profiles` | Base profiles to apply | `list(string)` | `[]` |
| `forgejo_url` | Forgejo instance URL | `string` | required |
| `runner_labels` | Runner labels for job matching | `string` | `"debian-trixie:host,linux_amd64:host"` |
| `runner_insecure` | Skip TLS verification | `bool` | `false` |
| `target_node` | Cluster node for container | `string` | `null` |
| `cpu_limit` | CPU limit | `string` | `"2"` |
| `memory_limit` | Memory limit | `string` | `"2GB"` |
| `enable_data_persistence` | Enable data volume | `bool` | `true` |
| `data_volume_name` | Data volume name | `string` | `"forgejo-runner-data"` |
| `data_volume_size` | Data volume size | `string` | `"20GB"` |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Container instance name |
| `ipv4_address` | Container IPv4 address |
| `ansible_vars` | Variables for Ansible configuration |
| `instance_info` | Instance info for dynamic inventory |

## Division of Responsibilities

### Terraform Manages

- Container creation/destruction
- Incus profile (CPU/memory limits)
- Storage volume for work directory
- Network attachment via base profiles
- Minimal cloud-init (Python3 for Ansible)

### Ansible Manages

- Forgejo runner binary download/installation
- Runner configuration file
- Forgejo registration
- Systemd service unit
- Labels and updates

## Execution Mode

This runner uses **host mode only** - jobs run directly in the container without Docker. This is simpler than Docker-in-Docker and sufficient for most CI workflows:

- Building and testing code
- Running scripts
- Deploying applications
- Any task that doesn't require container isolation

## Registration Token

The registration token is **not stored** in Terraform state. It's passed at runtime via environment variable:

```bash
FORGEJO_RUNNER_TOKEN=<token> make configure-runner-register ENV=cluster01
```

Registration is **idempotent** - if the `.runner` file already exists, registration is skipped.

## Troubleshooting

### Check runner status
```bash
incus exec cluster01:forgejo-runner01 -- systemctl status forgejo-runner
```

### View runner logs
```bash
incus exec cluster01:forgejo-runner01 -- journalctl -u forgejo-runner -f
```

### Re-register runner
```bash
# Remove existing registration
incus exec cluster01:forgejo-runner01 -- rm /etc/forgejo-runner/.runner

# Re-run registration
FORGEJO_RUNNER_TOKEN=<new-token> make configure-runner-register ENV=cluster01
```

### Check Forgejo UI
Navigate to Admin > Actions > Runners to see if the runner appears online.
