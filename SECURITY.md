# Security Documentation

This document describes the security architecture, controls, and best practices for the Atlas infrastructure.

## Table of Contents

- [Overview](#overview)
- [Threat Model](#threat-model)
- [Network Isolation](#network-isolation)
- [Secret Management](#secret-management)
- [TLS Configuration](#tls-configuration)
- [Access Control](#access-control)
- [Container Security](#container-security)
- [Security Headers](#security-headers)
- [Monitoring and Auditing](#monitoring-and-auditing)
- [Known Limitations](#known-limitations)
- [Recommended Additional Measures](#recommended-additional-measures)
- [Reporting Security Issues](#reporting-security-issues)

---

## Overview

Atlas implements a defense-in-depth security strategy with multiple layers:

1. **Network Segmentation** - Five isolated networks for different workload types
2. **Access Control** - IP-based restrictions and rate limiting
3. **TLS Encryption** - Internal PKI for service-to-service communication
4. **Container Isolation** - Non-root execution and resource limits
5. **Secret Protection** - File-based injection for sensitive credentials

---

## Threat Model

### What This Architecture Protects Against

| Threat | Mitigation |
|--------|------------|
| Unauthorized external access | IP allowlist, rate limiting, no direct service exposure |
| Brute force attacks | Rate limiting on login endpoints (10 req/min default) |
| Network sniffing | TLS encryption via internal CA |
| Container escape | Non-root users, resource limits, unprivileged containers |
| Credential exposure | File injection (not env vars), restrictive permissions |
| Cross-service attacks | Network segmentation, services only on required networks |
| DDoS/resource exhaustion | Hard memory limits, rate limiting |

### What This Architecture Does NOT Protect Against

| Threat | Limitation | Recommendation |
|--------|------------|----------------|
| Compromised host | Containers share kernel | Use VM-based isolation for high-security workloads |
| Supply chain attacks | Images from ghcr.io | Enable image signing, vulnerability scanning |
| Insider threats | Admin access to all services | Implement audit logging, RBAC |
| Zero-day exploits | No WAF or IDS | Add Cloudflare WAF, host-based IDS |
| Data at rest | No volume encryption | Enable storage pool encryption |

---

## Network Isolation

### Five-Network Architecture

Atlas uses five isolated bridge networks to segment workloads:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         External Access                              │
│                              │                                       │
│                        ┌─────┴─────┐                                │
│                        │  incusbr0 │ (external bridge)              │
│                        └─────┬─────┘                                │
│                              │                                       │
│                        ┌─────┴─────┐                                │
│                        │   Caddy   │ (reverse proxy)                │
│                        └───┬───┬───┘                                │
│                            │   │                                     │
│         ┌──────────────────┘   └──────────────────┐                 │
│         │                                          │                 │
│   ┌─────┴─────┐                            ┌──────┴─────┐           │
│   │Production │ 10.40.0.0/24               │ Management │ 10.50.0.0/24
│   │  Network  │                            │   Network  │           │
│   └───────────┘                            └────────────┘           │
│         │                                          │                 │
│   Public-facing                             Internal services        │
│   applications                              (Grafana, Prometheus,    │
│                                              Loki, step-ca)         │
│                                                                      │
│   ┌───────────┐  ┌───────────┐  ┌───────────┐                       │
│   │Development│  │  Testing  │  │  Staging  │                       │
│   │ 10.10.0.0 │  │ 10.20.0.0 │  │ 10.30.0.0 │                       │
│   └───────────┘  └───────────┘  └───────────┘                       │
│                                                                      │
│   Workload environments (isolated from each other)                   │
└─────────────────────────────────────────────────────────────────────┘
```

### Network Purposes

| Network | CIDR | Purpose | External Access |
|---------|------|---------|-----------------|
| development | 10.10.0.0/24 | Development workloads | NAT only |
| testing | 10.20.0.0/24 | Testing workloads | NAT only |
| staging | 10.30.0.0/24 | Staging workloads | NAT only |
| production | 10.40.0.0/24 | Production applications | Via Caddy |
| management | 10.50.0.0/24 | Internal services | Via Caddy (restricted) |

### Inter-Service Communication

- Services on the **same network** can communicate via `.incus` DNS (e.g., `prometheus01.incus`)
- Services on **different networks** cannot communicate directly
- **Caddy** has interfaces on production, management, and external networks to route traffic

### Profile Composition and NIC Naming

Each network profile uses a **semantic NIC name** to prevent conflicts during profile composition:

| Profile | NIC Name | Network |
|---------|----------|---------|
| management-network | `mgmt` | management |
| production-network | `prod` | production |
| development-network | `dev` | development |
| testing-network | `test` | testing |
| staging-network | `stage` | staging |

This allows containers to have multiple network interfaces without naming collisions.

---

## Secret Management

### Handling Principles

1. **Never commit secrets** - `terraform.tfvars` and `backend.hcl` are gitignored
2. **File injection over environment variables** - Secrets visible in `incus info` are avoided
3. **Restrictive permissions** - Secret files use mode `0400` (read-only by owner)
4. **Minimal exposure** - Secrets only injected where needed

### Secret Types and Handling

| Secret | Handling | File Mode | Notes |
|--------|----------|-----------|-------|
| Cloudflare API token | File injection | `0400` | `/etc/caddy/cloudflare_token` |
| Grafana admin password | Environment variable | N/A | Required by Grafana |
| step-ca provisioner password | Environment variable | N/A | Generated at init |
| Terraform state credentials | `backend.hcl` | N/A | Never committed |
| Cloudflare tunnel token | Environment variable | N/A | Required by cloudflared |

### Cloudflare Token Security

The Cloudflare API token is injected as a file rather than an environment variable:

```hcl
# In terraform/modules/caddy/main.tf
file {
  content     = var.cloudflare_api_token
  target_path = "/etc/caddy/cloudflare_token"
  mode        = "0400"  # Read-only for root
  uid         = 0
  gid         = 0
}
```

This prevents the token from appearing in:
- `incus info caddy01` output
- Process listings (`ps aux`)
- Container inspection tools

### terraform.tfvars Security

The `terraform.tfvars` file contains sensitive values:

```hcl
# Required secrets (example - do not commit actual values)
cloudflare_api_token     = "your-cloudflare-api-token"
grafana_admin_password   = "secure-admin-password"
cloudflared_tunnel_token = "your-tunnel-token"  # Optional
allowed_ip_range         = "192.168.1.0/24"     # Restrict access
```

**Best Practices:**
- Store in a password manager or secrets vault
- Use environment variables in CI/CD: `TF_VAR_cloudflare_api_token`
- Rotate credentials periodically
- Use the minimum required permissions for API tokens

---

## TLS Configuration

### Internal PKI with step-ca

Atlas includes an internal ACME Certificate Authority (step-ca) for automated TLS:

```
┌─────────────────────────────────────────────────────────────────┐
│                        step-ca (CA)                              │
│                             │                                    │
│           ┌─────────────────┼─────────────────┐                 │
│           │                 │                 │                  │
│           ▼                 ▼                 ▼                  │
│      ┌─────────┐      ┌──────────┐     ┌───────────┐           │
│      │ Grafana │      │Prometheus│     │   Loki    │           │
│      │  (TLS)  │      │  (TLS)   │     │   (TLS)   │           │
│      └─────────┘      └──────────┘     └───────────┘           │
│                                                                  │
│      Certificate Lifecycle:                                      │
│      • Duration: 24 hours (default)                             │
│      • Renewal: Automatic on container restart                  │
│      • Algorithm: ECDSA P-256                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Certificate Lifecycle

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Duration | 24 hours | Limits exposure if compromised |
| Renewal | Automatic | Via entrypoint scripts |
| Key algorithm | ECDSA P-256 | Modern, efficient |
| Root CA validity | 10 years | Reasonable for internal CA |

### Enabling TLS

TLS requires a two-phase deployment:

```bash
# Phase 1: Deploy step-ca
make deploy

# Get CA fingerprint
FINGERPRINT=$(incus exec step-ca01 -- cat /home/step/fingerprint)

# Phase 2: Enable TLS for services
# Edit main.tf to add:
#   enable_tls         = true
#   stepca_url         = "https://step-ca01.incus:9000"
#   stepca_fingerprint = "${FINGERPRINT}"
make deploy
```

### TLS Verification Settings

For internal services behind Caddy, TLS verification uses the internal CA:

```hcl
# Caddy trusts the internal CA for backend connections
reverse_proxy https://grafana01.incus:3000 {
  transport http {
    tls_trust_pool file /etc/caddy/internal-ca.crt
  }
}
```

For Grafana datasources connecting to Prometheus/Loki with self-signed certs:
- `tls_skip_verify` is set based on `tls_enabled` state
- This is acceptable for internal services where you control both endpoints

---

## Access Control

### IP-Based Restrictions

All public-facing services enforce IP-based access control:

```hcl
# In terraform.tfvars
allowed_ip_range = "192.168.68.0/22"  # Your network CIDR
```

The Caddyfile template implements this:

```
grafana.example.com {
    @denied not remote_ip 192.168.68.0/22
    abort @denied

    # ... rest of configuration
}
```

**Behavior:**
- Requests from allowed IPs proceed normally
- Requests from other IPs receive an immediate connection abort
- No error page or information leakage

### Rate Limiting

Rate limiting protects against brute force and DoS attacks:

| Endpoint Type | Default Limit | Window | Purpose |
|--------------|---------------|--------|---------|
| General | 100 requests | 1 minute | Prevent abuse |
| Login (`/login*`, `/api/login*`) | 10 requests | 1 minute | Prevent brute force |

Configuration in Terraform:

```hcl
module "grafana01" {
  # ...
  enable_rate_limiting      = true
  rate_limit_requests       = 100
  rate_limit_window         = "1m"
  login_rate_limit_requests = 10
  login_rate_limit_window   = "1m"
}
```

### Service Access Patterns

| Service | Network | External Access | Authentication |
|---------|---------|-----------------|----------------|
| Grafana | Management | Via Caddy (IP restricted) | Username/password |
| Prometheus | Management | None (internal only) | None |
| Loki | Management | None (internal only) | None |
| step-ca | Management | None (internal only) | ACME protocol |
| Alertmanager | Management | None (internal only) | None |
| Mosquitto | Production | Direct (ports 1883/8883) | Password file |
| Caddy | Multiple | Direct (ports 80/443) | N/A (proxy) |

---

## Container Security

### Non-Root Execution

All containers run as non-root users:

| Service | User | UID | Notes |
|---------|------|-----|-------|
| Grafana | grafana | 472 | Official Grafana UID |
| Prometheus | nobody | 65534 | Standard unprivileged |
| Loki | loki | 10001 | Official Loki UID |
| Alertmanager | nobody | 65534 | Standard unprivileged |
| Mosquitto | mosquitto | 1883 | Standard Mosquitto UID |
| step-ca | step | 1000 | Smallstep default |
| Caddy | root | 0 | Required for port binding |
| Node Exporter | N/A | N/A | Runs as container default |

### Storage Volume Permissions

Volumes are initialized with correct ownership:

```hcl
resource "incus_storage_volume" "grafana_data" {
  config = {
    "initial.uid"  = "472"   # grafana user
    "initial.gid"  = "472"   # grafana group
    "initial.mode" = "0755"
  }
}
```

### Automated Snapshot Scheduling

All storage volumes support automated snapshots for data protection:

```hcl
module "grafana01" {
  # ...
  enable_snapshots   = true
  snapshot_schedule  = "@daily"
  snapshot_expiry    = "7d"
}
```

Snapshots are disabled by default (`enable_snapshots = false`). See [BACKUP.md](BACKUP.md) for configuration details.

### Resource Limits

All containers enforce hard resource limits:

| Service | CPU | Memory | Memory Enforce |
|---------|-----|--------|----------------|
| Caddy | 2 | 1GB | hard |
| Grafana | 2 | 1GB | hard |
| Prometheus | 2 | 2GB | hard |
| Loki | 2 | 2GB | hard |
| step-ca | 1 | 512MB | hard |
| Alertmanager | 1 | 256MB | hard |
| Mosquitto | 1 | 256MB | hard |
| Node Exporter | 1 | 128MB | hard |
| Cloudflared | 1 | 256MB | hard |

**Hard memory enforcement** means the container will be OOM-killed rather than using swap, preventing noisy neighbor issues.

### Unprivileged Containers

All containers run unprivileged by default. Node Exporter explicitly sets:

```hcl
config = {
  "security.privileged" = "false"
}
```

### Read-Only Mounts

Node Exporter mounts host paths as read-only:

```hcl
device {
  name = "host-root"
  type = "disk"
  properties = {
    source   = "/"
    path     = "/host"
    readonly = "true"
  }
}
```

---

## Security Headers

Caddy automatically adds security headers to all responses:

```
header {
    # HSTS - force HTTPS for 1 year
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"

    # Prevent clickjacking
    X-Frame-Options "SAMEORIGIN"

    # Prevent MIME sniffing
    X-Content-Type-Options "nosniff"

    # Control referrer information
    Referrer-Policy "strict-origin-when-cross-origin"

    # Restrict browser features
    Permissions-Policy "geolocation=(), microphone=(), camera=()"

    # Remove server information
    -Server
}
```

### Header Explanations

| Header | Value | Purpose |
|--------|-------|---------|
| Strict-Transport-Security | 1 year + preload | Prevent SSL stripping attacks |
| X-Frame-Options | SAMEORIGIN | Prevent clickjacking |
| X-Content-Type-Options | nosniff | Prevent MIME confusion attacks |
| Referrer-Policy | strict-origin-when-cross-origin | Limit referrer leakage |
| Permissions-Policy | Deny geolocation, mic, camera | Disable unnecessary features |
| -Server | (removed) | Don't reveal server software |

---

## Monitoring and Auditing

### Metrics Collection

Security-relevant metrics are collected:

- **Incus metrics** (via mTLS) - Container resource usage, process counts
- **Node Exporter** - Host CPU, memory, disk, network statistics
- **Caddy metrics** - Request counts, response codes, latencies
- **Service metrics** - Application-specific health indicators

### Alert Rules

Prometheus includes security-relevant alert rules:

```yaml
# Service availability
- alert: ServiceDown
  expr: up == 0
  for: 2m

# Resource exhaustion
- alert: CriticalMemoryUsage
  expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.95
  for: 5m

# Disk space (potential log filling attack)
- alert: DiskSpaceCritical
  expr: node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1
  for: 5m
```

### Incus Logging to Loki

Container lifecycle events are automatically logged:

```hcl
resource "incus_config" "loki_logging" {
  config = {
    "loki.api.url"   = "http://loki01.incus:3100"
    "loki.types"     = "lifecycle,logging"
  }
}
```

Events captured:
- Container start/stop
- Container creation/deletion
- Configuration changes

---

## Known Limitations

### Current Security Gaps

1. **No volume encryption** - Data at rest is not encrypted
   - Mitigation: Use encrypted storage pool

2. **Shared kernel** - All containers share the host kernel
   - Mitigation: Use VMs for sensitive workloads

3. **No network policies** - Traffic within a network is unrestricted
   - Mitigation: Services only placed on required networks

4. **No image signing** - Images pulled without verification
   - Mitigation: Use digest pinning, enable Cosign

5. **No secrets rotation** - Manual credential rotation required
   - Mitigation: Implement HashiCorp Vault

6. **Limited audit logging** - No centralized audit trail
   - Mitigation: Enable host-level auditd

### Caddy Root Requirement

Caddy runs as root to bind to ports 80 and 443. This is mitigated by:
- Caddy's secure defaults and Go memory safety
- No sensitive data stored in Caddy container
- Rate limiting and IP restrictions

---

## Recommended Additional Measures

### High Priority

1. **Enable storage pool encryption**
   ```bash
   incus storage set local volume.zfs.encryption keylocation=prompt
   ```

2. **Add Cloudflare WAF** for public-facing services
   - Enable managed rulesets
   - Configure bot management

3. **Implement backup encryption**
   ```bash
   incus storage volume export local grafana01-data - | \
     gpg --symmetric --cipher-algo AES256 > backup.tar.gz.gpg
   ```

### Medium Priority

4. **Enable container image signing** with Cosign
   ```bash
   cosign sign ghcr.io/accuser/atlas/grafana:latest
   ```

5. **Add host-based intrusion detection** (AIDE, OSSEC)

6. **Implement log-based alerting** for security events

### Lower Priority

7. **Add network policies** using nftables rules

8. **Implement secrets rotation** via external vault

9. **Enable SELinux/AppArmor** profiles for containers

---

## Reporting Security Issues

If you discover a security vulnerability in Atlas:

1. **Do NOT** open a public GitHub issue
2. **Email** security concerns to the maintainer
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

Response timeline:
- Acknowledgment: 48 hours
- Initial assessment: 7 days
- Fix timeline: Dependent on severity

---

## References

- [Incus Security](https://linuxcontainers.org/incus/docs/main/security/)
- [Caddy Security](https://caddyserver.com/docs/automatic-https)
- [Smallstep Security](https://smallstep.com/docs/step-ca/certificate-authority-server-production/)
- [OWASP Security Headers](https://owasp.org/www-project-secure-headers/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
