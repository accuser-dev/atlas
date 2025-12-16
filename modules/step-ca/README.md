# step-ca Terraform Module

This module deploys step-ca, an internal ACME Certificate Authority, on Incus for automated TLS certificate management.

## Features

- **Internal PKI**: Private Certificate Authority for your infrastructure
- **ACME Protocol**: Automated certificate issuance and renewal
- **Short-Lived Certificates**: Default 24-hour certificates for security
- **Persistent Storage**: Secure storage for CA keys and configuration
- **DNS Name Support**: Configurable DNS names for the CA certificate
- **Profile Composition**: Works with base-infrastructure module profiles

## Usage

```hcl
module "step_ca01" {
  source = "./modules/step-ca"

  instance_name = "step-ca01"
  profile_name  = "step-ca"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  ca_name = "Atlas Internal CA"

  enable_data_persistence = true
  data_volume_name        = "step-ca01-data"
  data_volume_size        = "1GB"
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    step-ca Container                         │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                  step-ca Server                       │  │
│   │                                                       │  │
│   │   /home/step/certs/root_ca.crt  (Root CA cert)       │  │
│   │   /home/step/secrets/           (Private keys)       │  │
│   │   /home/step/config/            (CA configuration)   │  │
│   │   /home/step/fingerprint        (CA fingerprint)     │  │
│   │                                                       │  │
│   │   :9000/acme/acme/directory ───► ACME Endpoint       │  │
│   │   :9000/health              ───► Health Check        │  │
│   └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              ACME Clients                             │  │
│   │   • Grafana (enable_tls = true)                      │  │
│   │   • Prometheus (enable_tls = true)                   │  │
│   │   • Loki (enable_tls = true)                         │  │
│   │   • Mosquitto (enable_tls = true)                    │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Two-Phase Deployment

Since the CA fingerprint is generated at runtime, TLS configuration requires a two-phase deployment:

### Phase 1: Deploy step-ca

```bash
# Deploy infrastructure (step-ca generates fingerprint)
make deploy

# Retrieve the CA fingerprint
incus exec step-ca01 -- cat /home/step/fingerprint
# Example output: abc123def456...
```

### Phase 2: Enable TLS for Services

Update your module configurations with the fingerprint:

```hcl
module "grafana01" {
  # ...
  enable_tls         = true
  stepca_url         = module.step_ca01.acme_endpoint
  stepca_fingerprint = "abc123def456..."  # From Phase 1
}

module "prometheus01" {
  # ...
  enable_tls         = true
  stepca_url         = module.step_ca01.acme_endpoint
  stepca_fingerprint = "abc123def456..."
}
```

Then re-deploy:

```bash
make deploy
```

## Certificate Lifecycle

- **Duration**: 24 hours by default (configurable via `cert_duration`)
- **Renewal**: Services automatically renew certificates on container restart
- **Storage**: Certificates stored in `/etc/<service>/tls/` inside client containers
- **Root CA**: Available at `/home/step/certs/root_ca.crt` in step-ca container

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the step-ca instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `profiles` | List of Incus profile names to apply | `list(string)` | `["default"]` | no |
| `image` | Container image to use | `string` | `"ghcr:accuser-dev/atlas/step-ca:latest"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit (e.g., "512MB") | `string` | `"512MB"` | no |
| `storage_pool` | Storage pool for the data volume | `string` | `"local"` | no |
| `ca_name` | Name of the Certificate Authority | `string` | `"Atlas Internal CA"` | no |
| `ca_dns_names` | Additional DNS names for CA certificate | `string` | `""` | no |
| `ca_password` | Password for CA private keys | `string` | `""` | no |
| `cert_duration` | Default certificate duration (e.g., "24h") | `string` | `"24h"` | no |
| `enable_data_persistence` | Enable persistent storage | `bool` | `true` | no |
| `data_volume_name` | Name of the storage volume | `string` | `"step-ca-data"` | no |
| `data_volume_size` | Size of storage volume (min 100MB) | `string` | `"1GB"` | no |
| `acme_port` | Port for ACME endpoint | `string` | `"9000"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `acme_endpoint` | ACME endpoint URL (e.g., `https://step-ca01.incus:9000`) |
| `acme_directory` | Full ACME directory URL for clients |
| `root_ca_path` | Path to root CA certificate in container |
| `ca_name` | Name of the Certificate Authority |
| `fingerprint_command` | Command to retrieve CA fingerprint |
| `fingerprint_file_path` | Path to fingerprint file in container |

## Troubleshooting

### Check step-ca health

```bash
incus exec step-ca01 -- step ca health \
  --ca-url https://localhost:9000 \
  --root /home/step/certs/root_ca.crt
```

### View CA certificate details

```bash
incus exec step-ca01 -- step certificate inspect /home/step/certs/root_ca.crt
```

### Retrieve CA fingerprint

```bash
incus exec step-ca01 -- cat /home/step/fingerprint
```

### Test certificate request manually

```bash
incus exec step-ca01 -- step ca certificate test.local /tmp/test.crt /tmp/test.key \
  --provisioner acme \
  --ca-url https://localhost:9000
```

### View CA configuration

```bash
incus exec step-ca01 -- cat /home/step/config/ca.json
```

### Check CA logs

```bash
incus exec step-ca01 -- cat /home/step/logs/ca.log
```

### Verify ACME endpoint

```bash
# From another container on the management network
curl -k https://step-ca01.incus:9000/acme/acme/directory
```

## DNS Names Configuration

By default, the CA certificate includes:
- `<instance_name>.incus` (e.g., `step-ca01.incus`)
- `localhost`

Add additional DNS names for the CA certificate:

```hcl
module "step_ca01" {
  # ...
  ca_dns_names = "step-ca.example.com,pki.internal"
}
```

## Security Considerations

1. **Protect the CA**: The step-ca container holds private keys; restrict access
2. **Short-Lived Certificates**: 24-hour default reduces impact of key compromise
3. **Persistent Storage**: CA data survives restarts but must be backed up
4. **Fingerprint Trust**: Services verify the CA via its fingerprint (TOFU model)
5. **Internal Only**: Run on management network, not publicly accessible

## Backup and Recovery

The CA data volume contains critical cryptographic material:

```bash
# Backup CA data
incus storage volume snapshot local step-ca01-data backup-$(date +%Y%m%d)

# List snapshots
incus storage volume list local --format csv | grep step-ca

# Restore from snapshot (requires container to be stopped)
incus stop step-ca01
incus storage volume restore local step-ca01-data backup-20240101
incus start step-ca01
```

## Related Modules

- [grafana](../grafana/) - Enable TLS for Grafana
- [prometheus](../prometheus/) - Enable TLS for Prometheus
- [loki](../loki/) - Enable TLS for Loki
- [mosquitto](../mosquitto/) - Enable TLS for MQTT
- [base-infrastructure](../base-infrastructure/) - Provides base profiles

## References

- [step-ca Documentation](https://smallstep.com/docs/step-ca)
- [ACME Protocol](https://datatracker.ietf.org/doc/html/rfc8555)
- [step CLI Reference](https://smallstep.com/docs/step-cli)
- [Certificate Management Best Practices](https://smallstep.com/blog/everything-pki/)
