variable "config" {
  type = object({
    gotify_token       = string
    dockerhub_username = string
    dockerhub_password = string
    ghcr_username      = string
    ghcr_password      = string
    oidc_client_id     = string
    oidc_client_secret = string
  })
}

variable "target" {
  type = string
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "public_domain" {
  type = string
}

