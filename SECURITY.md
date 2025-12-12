# Security Documentation

This document describes the security architecture, controls, and best practices for the Atlas infrastructure.

## Table of Contents

- [Overview](#overview)
- [Threat Model](#threat-model)
- [Network Isolation](#network-isolation)
- [Secret Management](#secret-management)
- [Secret Rotation](#secret-rotation)
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

1. **Network Segmentation** - Two isolated networks (three with GitOps enabled) for workload separation
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

### Network Architecture

Atlas uses two isolated bridge networks to segment workloads (three when GitOps is enabled):

```
┌─────────────────────────────────────────────────────────────────────┐
│                         External Access                              │
│                              │                                       │
│                        ┌─────┴─────┐                                │
│                        │  incusbr0 │ (external bridge)              │
│                        └─────┬─────┘                                │
│                              │                                       │
│              ┌───────────────┼───────────────┐                      │
│              │               │               │                       │
│        ┌─────┴─────┐   ┌─────┴─────┐   ┌─────┴─────┐               │
│        │   Caddy   │   │           │   │Caddy-GitOps│               │
│        └───┬───┬───┘   │           │   └─────┬─────┘               │
│            │   │       │           │         │                       │
│     ┌──────┘   └────┐  │           │         │                       │
│     │               │  │           │         │                       │
│ ┌───┴───────┐  ┌────┴──┴───┐  ┌────┴─────────┴───┐                  │
│ │Production │  │Management │  │     GitOps       │                  │
│ │10.10.0.0  │  │10.20.0.0  │  │   10.30.0.0      │                  │
│ └───────────┘  └───────────┘  └──────────────────┘                  │
│      │              │                │                               │
│  Mosquitto     Grafana           Atlantis                           │
│              Prometheus         (optional)                          │
│                 Loki                                                 │
│               step-ca                                                │
│            Alertmanager                                              │
│            Node Exporter                                             │
└─────────────────────────────────────────────────────────────────────┘
```

### Network Purposes

| Network | CIDR | Purpose | External Access |
|---------|------|---------|-----------------|
| production | 10.10.0.0/24 | Public-facing services | Via Caddy |
| management | 10.20.0.0/24 | Internal services | Via Caddy (restricted) |
| gitops | 10.30.0.0/24 | GitOps automation (optional) | Via Caddy-GitOps |

### Inter-Service Communication

- Services on the **same network** can communicate via `.incus` DNS (e.g., `prometheus01.incus`)
- Services on **different networks** cannot communicate directly
- **Caddy** has interfaces on production, management, and external networks to route traffic
- **Caddy-GitOps** (optional) has interfaces on gitops and external networks for webhook traffic

### Profile Composition and NIC Naming

Each network profile uses a **semantic NIC name** to prevent conflicts during profile composition:

| Profile | NIC Name | Network |
|---------|----------|---------|
| production-network | `prod` | production |
| management-network | `mgmt` | management |
| gitops-network | `gitops` | gitops |

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

## Secret Rotation

This section documents procedures for rotating each secret type in the infrastructure.

### Rotation Schedule Recommendations

| Secret Type | Recommended Frequency | Risk Level |
|-------------|----------------------|------------|
| Cloudflare API Token | 90 days | High |
| Grafana Admin Password | 90 days | Medium |
| Cloudflared Tunnel Token | On compromise only | High |
| step-ca Root Certificate | 5-10 years | Critical |
| Incus Metrics Certificate | 5-10 years | Low |
| GitHub Token (Atlantis) | 90 days | High |
| GitHub Webhook Secret | 90 days | Medium |
| MQTT User Passwords | 90 days | Medium |

### Cloudflare API Token

**Impact:** Affects Caddy's ability to obtain/renew HTTPS certificates via DNS-01 challenge.

**Rotation Procedure:**

```bash
# 1. Generate new token in Cloudflare dashboard
#    https://dash.cloudflare.com/profile/api-tokens
#    Permissions needed: Zone:DNS:Edit for your domain

# 2. Test the new token (optional but recommended)
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer NEW_TOKEN_HERE"

# 3. Update terraform.tfvars
cloudflare_api_token = "new-token-value"

# 4. Apply the change (updates Caddy container)
cd terraform && tofu apply

# 5. Verify certificate renewal works
incus exec caddy01 -- caddy reload --config /etc/caddy/Caddyfile

# 6. Revoke old token in Cloudflare dashboard
```

**Verification:**
```bash
# Check Caddy logs for certificate operations
incus exec caddy01 -- docker logs caddy 2>&1 | grep -i "certificate\|acme"
```

**Zero-downtime:** Yes - existing certificates remain valid during rotation.

### Grafana Admin Password

**Impact:** Admin access to Grafana dashboards and configuration.

**Rotation Procedure:**

```bash
# Option A: Via Grafana UI (preferred)
# 1. Log into Grafana as admin
# 2. Navigate to Profile (bottom left) → Change Password
# 3. Update terraform.tfvars for consistency:
grafana_admin_password = "new-password"

# Option B: Via Terraform (forces container recreation)
# 1. Update terraform.tfvars
grafana_admin_password = "new-password"

# 2. Apply change
cd terraform && tofu apply

# Note: Option B may cause brief downtime as container is recreated
```

**Verification:**
```bash
# Test login with new password
curl -u admin:new-password https://grafana.yourdomain.com/api/health
```

**Zero-downtime:** Option A: Yes. Option B: Brief downtime during container recreation.

### Cloudflared Tunnel Token

**Impact:** Cloudflare Tunnel connectivity - service will disconnect if token is invalid.

**Rotation Procedure:**

```bash
# 1. In Cloudflare Zero Trust dashboard:
#    https://one.dash.cloudflare.com/
#    Navigate to: Access → Tunnels → Your Tunnel → Configure

# 2. Generate new token (will invalidate old token immediately)
#    Warning: This causes immediate disconnection!

# 3. Update terraform.tfvars immediately
cloudflared_tunnel_token = "new-token-value"

# 4. Apply change as quickly as possible
cd terraform && tofu apply

# 5. Verify tunnel reconnects
incus exec cloudflared01 -- docker logs cloudflared 2>&1 | tail -20
```

**Verification:**
```bash
# Check tunnel status in Cloudflare dashboard or:
incus exec cloudflared01 -- docker logs cloudflared 2>&1 | grep -i "connected\|registered"
```

**Zero-downtime:** No - there will be a brief outage between token rotation and applying the new token. Plan for 1-5 minutes of downtime.

### step-ca Root Certificate

**Impact:** Critical - all internal TLS certificates depend on this CA.

**Rotation Procedure:**

⚠️ **Warning:** Rotating the root CA requires re-issuing ALL service certificates. This is a major operation.

```bash
# 1. Create backup of current CA data
incus snapshot step-ca01 pre-rotation
incus storage volume snapshot local step-ca01-data pre-rotation

# 2. Plan maintenance window - all TLS-enabled services will need restart

# 3. Delete step-ca data volume (will regenerate CA on restart)
incus stop step-ca01
incus storage volume delete local step-ca01-data
incus start step-ca01

# 4. Get new CA fingerprint
NEW_FINGERPRINT=$(incus exec step-ca01 -- cat /home/step/fingerprint)
echo "New fingerprint: $NEW_FINGERPRINT"

# 5. Update all services with new fingerprint
# Edit main.tf to update stepca_fingerprint for each TLS-enabled service

# 6. Apply changes (restarts all TLS-enabled services)
cd terraform && tofu apply

# 7. Verify each service obtained new certificate
for svc in grafana01 prometheus01 loki01; do
  echo "=== $svc ==="
  incus exec $svc -- docker logs $(incus exec $svc -- docker ps -q) 2>&1 | grep -i "certificate"
done
```

**Verification:**
```bash
# Check CA health
incus exec step-ca01 -- step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt

# Verify certificate chain for a service
incus exec grafana01 -- openssl s_client -connect localhost:3000 -CAfile /etc/grafana/tls/ca.crt
```

**Zero-downtime:** No - all TLS-enabled services require restart. Plan for 5-15 minutes of downtime.

### Incus Metrics Certificate

**Impact:** Prometheus will be unable to scrape Incus container metrics.

**Rotation Procedure:**

```bash
# 1. Taint the certificate resources to force regeneration
cd terraform
tofu taint 'module.incus_metrics[0].tls_private_key.metrics'
tofu taint 'module.incus_metrics[0].tls_self_signed_cert.metrics'

# 2. Apply to generate new certificate
tofu apply

# 3. Verify Prometheus can scrape metrics
incus exec prometheus01 -- wget -q -O- http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="incus")'
```

**Verification:**
```bash
# Check Prometheus targets page for incus job status
curl -s http://prometheus01.incus:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="incus") | {health: .health, lastError: .lastError}'
```

**Zero-downtime:** Yes - brief gap in metrics during certificate rotation.

### GitHub Token (Atlantis)

**Impact:** Atlantis will be unable to post plan/apply comments or clone repositories.

**Rotation Procedure:**

```bash
# 1. Generate new Personal Access Token in GitHub
#    https://github.com/settings/tokens
#    Required scopes: repo (full control)

# 2. Update terraform.tfvars
atlantis_github_token = "ghp_new_token_here"

# 3. Apply change
cd terraform && tofu apply

# 4. Verify by opening a test PR or checking Atlantis logs
incus exec atlantis01 -- docker logs atlantis 2>&1 | tail -20

# 5. Revoke old token in GitHub
#    https://github.com/settings/tokens
```

**Verification:**
```bash
# Test GitHub API access
incus exec atlantis01 -- wget -q -O- \
  --header="Authorization: token $(cat /atlantis-data/.atlantis/token)" \
  https://api.github.com/user
```

**Zero-downtime:** Yes - existing operations continue until old token expires.

### GitHub Webhook Secret (Atlantis)

**Impact:** GitHub webhook deliveries will fail validation.

**Rotation Procedure:**

```bash
# 1. Generate new secret
NEW_SECRET=$(openssl rand -hex 32)
echo "New webhook secret: $NEW_SECRET"

# 2. Update terraform.tfvars
atlantis_github_webhook_secret = "new-secret-value"

# 3. Apply change to Atlantis
cd terraform && tofu apply

# 4. Update webhook in GitHub repository settings
#    https://github.com/YOUR_ORG/YOUR_REPO/settings/hooks
#    Edit the Atlantis webhook → Update secret

# 5. Test by making a small commit or re-delivering a webhook
```

**Verification:**
```bash
# Check Atlantis logs for webhook validation
incus exec atlantis01 -- docker logs atlantis 2>&1 | grep -i "webhook\|signature"
```

**Zero-downtime:** Brief gap - webhooks will fail between Atlantis update and GitHub webhook update. Update quickly.

### MQTT User Passwords (Mosquitto)

**Impact:** MQTT clients using rotated credentials will disconnect.

**Rotation Procedure:**

```bash
# 1. Update terraform.tfvars with new passwords
mqtt_users = {
  "sensor1" = "new-secure-password"
  "app1"    = "another-new-password"
}

# 2. Apply change
cd terraform && tofu apply

# 3. Update MQTT clients with new credentials
# (application-specific)

# 4. Verify connections
incus exec mosquitto01 -- mosquitto_sub -h localhost -u sensor1 -P new-secure-password -t test -C 1
```

**Zero-downtime:** No - clients must be updated with new credentials.

### Emergency Rotation (Compromised Secrets)

If you suspect a secret has been compromised:

```bash
# 1. IMMEDIATELY rotate the affected secret using procedures above

# 2. Check logs for unauthorized access
# Grafana:
incus exec grafana01 -- docker logs grafana 2>&1 | grep -i "login\|auth\|failed"

# Caddy:
incus exec caddy01 -- docker logs caddy 2>&1 | grep -i "error\|denied"

# Atlantis:
incus exec atlantis01 -- docker logs atlantis 2>&1 | grep -i "webhook\|unauthorized"

# 3. Review Incus lifecycle logs in Loki/Grafana
# Query: {job="incus"} |= "lifecycle"

# 4. If GitHub token compromised:
#    - Immediately revoke at https://github.com/settings/tokens
#    - Review repository audit log: https://github.com/ORG/REPO/settings/security_analysis
#    - Check for unauthorized commits, releases, or settings changes

# 5. If Cloudflare token compromised:
#    - Revoke immediately in dashboard
#    - Review Cloudflare audit logs
#    - Check for unauthorized DNS changes

# 6. Document incident and update rotation schedule
```

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
| Atlantis | GitOps | Via Caddy-GitOps (GitHub IPs) | Webhook secret |
| Caddy-GitOps | GitOps | Direct (ports 80/443) | N/A (proxy) |

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
| Caddy-GitOps | root | 0 | Required for port binding |
| Node Exporter | N/A | N/A | Runs as container default |
| Atlantis | atlantis | 100 | Official Atlantis UID |

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
| Caddy-GitOps | 1 | 256MB | hard |
| Grafana | 2 | 1GB | hard |
| Prometheus | 2 | 2GB | hard |
| Loki | 2 | 2GB | hard |
| step-ca | 1 | 512MB | hard |
| Alertmanager | 1 | 256MB | hard |
| Mosquitto | 1 | 256MB | hard |
| Node Exporter | 1 | 128MB | hard |
| Cloudflared | 1 | 256MB | hard |
| Atlantis | 2 | 1GB | hard |

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

5. **Manual secrets rotation** - Rotation procedures documented but not automated
   - Mitigation: See [Secret Rotation](#secret-rotation) section; consider HashiCorp Vault for automation

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
   cosign sign ghcr.io/accuser-dev/atlas/grafana:latest
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
