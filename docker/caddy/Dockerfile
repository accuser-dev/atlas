# Custom Caddy with Cloudflare DNS plugin
# Pinned to v2.10.2 for reproducibility and security
FROM caddybuilds/caddy-cloudflare:2.10.2

# Add any custom Caddy modules or configuration here
# Example: COPY custom-plugins /usr/local/bin/

# The Caddyfile will be managed by Terraform and injected at runtime
# No need to copy it here unless you want a default fallback

LABEL maintainer="hello@accuser.dev"
LABEL description="Custom Caddy reverse proxy with Cloudflare DNS support"
