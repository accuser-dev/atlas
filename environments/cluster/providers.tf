# Incus provider configuration for cluster environment
# This connects to the 3-node cluster via Incus remote
#
# Configure the remote before running:
#   incus remote add cluster01 https://<cluster-ip>:8443
#   incus remote switch cluster01
#
# Or set environment variable:
#   export INCUS_REMOTE=cluster01

provider "incus" {
  # The provider uses the current Incus remote from client config
  # or INCUS_REMOTE environment variable
  generate_client_certificates = true
  accept_remote_certificate    = var.accept_remote_certificate
}
