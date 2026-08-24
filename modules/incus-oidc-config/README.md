# incus-oidc-config

Configures the Incus daemon's own OIDC login (`oidc.issuer`, `oidc.client.id`,
`oidc.scopes`, `oidc.claim`, `oidc.audience`) via the `incus_server` resource.

Previously this was a manual step - the environment's `incus_oidc_config`
output printed the `incus config set ...` commands to run by hand. This
module applies them directly.

## Why the issuer needs a public CA

The issuer's TLS certificate must be one Incus's default trust store already
trusts. An internally-issued cert (e.g. from this repo's step-ca) won't work
without a way to add a custom trusted CA to the Incus daemon, which doesn't
exist for this purpose - use a publicly-trusted OIDC provider (e.g. an
IdP-hosted or forum SSO) as the issuer instead.

## Usage

```hcl
module "incus_oidc" {
  source = "../../modules/incus-oidc-config"

  issuer    = "https://sso.linuxcontainers.org"
  client_id = "387573419052444795"
  scopes    = "openid,offline_access"
  claim     = "preferred_username"
}
```

## Variables

| Name        | Description                                       | Default                     |
| ----------- | -------------------------------------------------- | ---------------------------- |
| `issuer`    | OIDC issuer URL (must be `https://`)                | required                     |
| `client_id` | OIDC client ID registered with the issuer           | required                     |
| `scopes`    | Comma-separated scopes to request                   | `openid,offline_access`      |
| `claim`     | Claim used to identify the user                     | `email`                      |
| `audience`  | Audience to verify tokens against (provider-dependent) | `""` (omitted from config) |

## Outputs

| Name        | Description               |
| ----------- | -------------------------- |
| `issuer`    | Configured OIDC issuer URL |
| `client_id` | Configured OIDC client ID  |
