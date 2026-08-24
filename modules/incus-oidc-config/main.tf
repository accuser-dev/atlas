# =============================================================================
# Incus OIDC Configuration Module
# =============================================================================
# Configures the Incus daemon's own OIDC login (server config keys
# oidc.issuer / oidc.client.id / oidc.audience / oidc.scopes / oidc.claim).
#
# This was previously a manual step (see the old `incus_oidc_config` output)
# because the OIDC issuer originally used was dex01, whose TLS certificate is
# signed by this repo's internal step-ca - Incus has no way to be told to
# trust that CA, so the issuer generally needs a publicly-trusted certificate
# (e.g. a forum/IdP-hosted OIDC provider) for this to work reliably.

resource "incus_server" "oidc" {
  config = merge(
    {
      "oidc.issuer"    = var.issuer
      "oidc.client.id" = var.client_id
      "oidc.scopes"    = var.scopes
      "oidc.claim"     = var.claim
    },
    var.audience != "" ? { "oidc.audience" = var.audience } : {}
  )
}
