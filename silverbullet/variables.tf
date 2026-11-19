variable "secrets" {
  type = object({
    oidc_client_id     = string
    oidc_client_secret = string
    admin_password     = string
  })
}

variable "target" {
  type = string
}

variable "snapshots" {
  type    = map(string)
  default = {}
}

variable "public_domain" {
  type = string
}

variable "versions" {
  type = object({
    silverbullet = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
