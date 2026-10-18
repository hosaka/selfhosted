variable "secrets" {
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

variable "snapshots" {
  type    = map(string)
  default = {}
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

variable "versions" {
  type = object({
    gotify = string
    diun   = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
