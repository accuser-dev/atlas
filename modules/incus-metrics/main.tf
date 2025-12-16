# Generate private key for metrics certificate
resource "tls_private_key" "metrics" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# Generate self-signed certificate for metrics collection
resource "tls_self_signed_cert" "metrics" {
  private_key_pem = tls_private_key.metrics.private_key_pem

  subject {
    common_name = var.certificate_common_name
  }

  validity_period_hours = var.certificate_validity_days * 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# Register the certificate with Incus as a metrics certificate
resource "incus_certificate" "metrics" {
  name        = var.certificate_name
  description = var.certificate_description
  type        = "metrics"
  certificate = tls_self_signed_cert.metrics.cert_pem
}

locals {
  # Extract server name from address if not explicitly provided
  server_name = var.incus_server_name != "" ? var.incus_server_name : split(":", var.incus_server_address)[0]
}
