# Incus Metrics Module

This module generates and manages mTLS certificates for Prometheus to scrape container metrics from the Incus API.

## Overview

Incus exposes container-level metrics (CPU, memory, disk, network, processes) via its REST API at `/1.0/metrics`. Access requires a certificate of type `metrics` registered with Incus. This module automates the entire certificate lifecycle:

1. Generates an ECDSA P-384 private key
2. Creates a self-signed certificate valid for 10 years
3. Registers the certificate with Incus as type `metrics`
4. Outputs the certificate and key for injection into Prometheus

## Usage

```hcl
module "incus_metrics" {
  source = "./modules/incus-metrics"

  certificate_name     = "prometheus-metrics"
  incus_server_address = "10.50.0.1:8443"
}

# Pass certificates to Prometheus module
module "prometheus01" {
  source = "./modules/prometheus"

  # ... other configuration ...

  incus_metrics_certificate = module.incus_metrics.metrics_certificate_pem
  incus_metrics_private_key = module.incus_metrics.metrics_private_key_pem
}
```

## Requirements

| Name | Version |
|------|---------|
| incus | >= 1.0.0 |
| tls | >= 4.0.0 |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `certificate_name` | Name for the metrics certificate in Incus | `string` | `"prometheus-metrics"` |
| `certificate_description` | Description for the metrics certificate | `string` | `"Metrics certificate for Prometheus scraping"` |
| `certificate_validity_days` | Number of days the certificate is valid | `number` | `3650` |
| `certificate_common_name` | Common name for the certificate | `string` | `"metrics.local"` |
| `incus_server_address` | Address of the Incus server (e.g., `10.50.0.1:8443`) | `string` | **required** |
| `incus_server_name` | Server name for TLS verification (defaults to hostname from address) | `string` | `""` |

## Outputs

| Name | Description |
|------|-------------|
| `metrics_certificate_pem` | The metrics certificate in PEM format |
| `metrics_private_key_pem` | The metrics private key in PEM format |
| `certificate_fingerprint` | Fingerprint of the registered metrics certificate |
| `incus_server_address` | The Incus server address for metrics endpoint |
| `server_name` | Server name for TLS verification |
| `prometheus_scrape_config` | Ready-to-use Prometheus scrape configuration (YAML) |

## Available Metrics

Once configured, Prometheus will collect these Incus metrics:

| Metric | Type | Description |
|--------|------|-------------|
| `incus_cpu_seconds_total` | counter | Total CPU time consumed per container |
| `incus_cpu_effective_total` | gauge | Effective CPU count per container |
| `incus_memory_*` | gauge | Memory usage statistics |
| `incus_disk_read_bytes_total` | counter | Disk read bytes |
| `incus_disk_written_bytes_total` | counter | Disk written bytes |
| `incus_network_receive_bytes_total` | counter | Network bytes received |
| `incus_network_transmit_bytes_total` | counter | Network bytes transmitted |
| `incus_procs_total` | gauge | Process count per container |

## Grafana Dashboard

Import the official Incus dashboard from Grafana.com:
- Dashboard ID: **19727**
- Name: "Incus"

## Security Notes

- The certificate and private key are marked as `sensitive` in Terraform
- Certificate uses ECDSA P-384 curve (same as recommended by Incus documentation)
- The certificate is registered with restricted `metrics` type (cannot access full Incus API)

### TLS Server Verification

By default, the Prometheus configuration uses `insecure_skip_verify: true` for the Incus metrics endpoint because Incus uses a self-signed certificate.

**To enable proper TLS verification** (recommended if you have ACME configured for Incus):

1. Check if Incus has ACME configured:
   ```bash
   incus config get acme.domain
   ```

2. If it returns a domain (e.g., `incus.example.com`), set the variable in `terraform.tfvars`:
   ```hcl
   incus_metrics_server_name = "incus.example.com"
   ```

3. Apply the configuration - Prometheus will now verify the server certificate.

**When TLS verification is disabled (default):**

- Traffic is still restricted to the internal management network
- mTLS client authentication is still enforced (Incus validates our certificate)
- Risk: Vulnerable to MITM attacks on the internal network

See [GitHub Issue #112](https://github.com/accuser/atlas/issues/112) for discussion.

## Troubleshooting

**Verify certificate is registered:**
```bash
incus config trust list --format csv | grep metrics
```

**Test metrics endpoint manually:**
```bash
curl -k --cert metrics.crt --key metrics.key https://10.50.0.1:8443/1.0/metrics
```

**Check Prometheus targets:**
```bash
incus exec prometheus01 -- wget -q -O - 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.job=="incus")'
```
