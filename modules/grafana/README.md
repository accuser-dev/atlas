# Grafana Terraform Module

This module deploys a Grafana instance on Incus with automatic reverse proxy configuration via Caddy.

## Features

- **Debian Trixie**: Uses Debian Trixie system container with systemd
- **Persistent Storage**: Optional data volume for dashboards and configuration
- **Network Isolation**: Connects to management network for internal services
- **Reverse Proxy**: Automatic Caddy configuration with HTTPS
- **Security Headers**: Industry-standard HTTP security headers
- **IP Restrictions**: Access control via IP allowlists
- **Systemd Integration**: Proper service management

## Usage

```hcl
module "grafana01" {
  source = "./modules/grafana"

  instance_name = "grafana01"
  profile_name  = "grafana01"
  network_name  = incus_network.management.name

  domain           = "grafana.example.com"
  allowed_ip_range = "192.168.1.0/24"

  environment_variables = {
    GF_SECURITY_ADMIN_USER     = var.grafana_admin_user
    GF_SECURITY_ADMIN_PASSWORD = var.grafana_admin_password
  }

  enable_data_persistence = true
  data_volume_name        = "grafana01-data"
  data_volume_size        = "10GB"
}
```

## Security Headers

The module automatically configures the following security headers in the Caddy reverse proxy:

### HTTP Strict Transport Security (HSTS)
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```
- Forces HTTPS for 1 year
- Applies to all subdomains
- Eligible for browser HSTS preload lists

### X-Frame-Options
```
X-Frame-Options: SAMEORIGIN
```
- Prevents clickjacking attacks
- Allows Grafana to embed its own content in iframes
- Blocks embedding from external domains

### X-Content-Type-Options
```
X-Content-Type-Options: nosniff
```
- Prevents MIME-type confusion attacks
- Forces browsers to respect declared content types

### Referrer-Policy
```
Referrer-Policy: strict-origin-when-cross-origin
```
- Protects against referrer leakage
- Sends full referrer for same-origin requests
- Sends only origin for cross-origin requests

### Permissions-Policy
```
Permissions-Policy: geolocation=(), microphone=(), camera=()
```
- Restricts browser feature access
- Prevents unauthorized use of device sensors
- Reduces attack surface

### Server Header Removal
```
-Server
```
- Removes the Server header from responses
- Reduces information disclosure

## Testing Security Headers

After deployment, verify headers are correctly set:

```bash
# Using curl
curl -I https://grafana.example.com

# Using online tools
# https://securityheaders.com/
# https://observatory.mozilla.org/
```

Expected output:
```
HTTP/2 200
strict-transport-security: max-age=31536000; includeSubDomains; preload
x-frame-options: SAMEORIGIN
x-content-type-options: nosniff
referrer-policy: strict-origin-when-cross-origin
permissions-policy: geolocation=(), microphone=(), camera=()
```

## Content Security Policy (CSP)

Currently, CSP is **not** configured by default because:
- Grafana's UI uses inline scripts and styles
- Grafana loads resources from CDNs (for some plugins)
- CSP requires careful tuning per deployment

To add CSP, customize the template or add to `environment_variables`:
```hcl
environment_variables = {
  GF_SECURITY_CONTENT_SECURITY_POLICY = "true"
  GF_SECURITY_CONTENT_SECURITY_POLICY_TEMPLATE = "script-src 'self' 'unsafe-eval' 'unsafe-inline';"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the Incus instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `network_name` | Incus network to connect to | `string` | n/a | yes |
| `domain` | Domain name for Caddy reverse proxy | `string` | n/a | yes |
| `allowed_ip_range` | CIDR range for IP allowlist | `string` | n/a | yes |
| `image` | Container image to use | `string` | `"images:debian/trixie/cloud"` | no |
| `cpu_limit` | CPU limit | `number` | `2` | no |
| `memory_limit` | Memory limit | `string` | `"1GB"` | no |
| `port` | Internal HTTP port | `number` | `3000` | no |
| `environment_variables` | Environment variables | `map(string)` | `{}` | no |
| `enable_data_persistence` | Enable persistent storage | `bool` | `true` | no |
| `data_volume_name` | Name of data volume | `string` | `"grafana-data"` | no |
| `data_volume_size` | Size of data volume | `string` | `"10GB"` | no |
| `data_volume_pool` | Storage pool for data volume | `string` | `"local"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | The name of the Grafana instance |
| `caddy_config_block` | Caddy configuration block for this instance |

## References

- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [Caddy Header Directive](https://caddyserver.com/docs/caddyfile/directives/header)
- [Grafana Security Documentation](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/)
- [Mozilla Observatory](https://observatory.mozilla.org/)
- [SecurityHeaders.com](https://securityheaders.com/)
