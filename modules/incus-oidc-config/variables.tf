# =============================================================================
# Incus OIDC Configuration Module Variables
# =============================================================================

variable "issuer" {
  description = "OIDC issuer URL Incus should trust for login"
  type        = string

  validation {
    condition     = can(regex("^https://", var.issuer))
    error_message = "issuer must be an https:// URL."
  }
}

variable "client_id" {
  description = "OIDC client ID registered with the issuer for Incus"
  type        = string
}

variable "scopes" {
  description = "Comma-separated OIDC scopes to request"
  type        = string
  default     = "openid,offline_access"
}

variable "claim" {
  description = "Claim used to identify the authenticated user/subject"
  type        = string
  default     = "email"
}

variable "audience" {
  description = "Audience OIDC tokens should be verified against (optional, provider-dependent)"
  type        = string
  default     = ""
}
