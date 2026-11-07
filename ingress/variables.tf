
variable "secrets" {
  type = object({
    frp_server_addr           = string
    frp_auth_token            = string
    frps_dashboard_secret_key = string
    acme_email                = string
  })
}

# For the DNS challenge, only allowed to write the `_acme-challenge` records
variable "desec_token" {
  type      = string
  sensitive = true
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
    frpc  = string
    caddy = string
  })
}

variable "services" {
  type = list(object({
    name       = string
    caddy      = optional(string, "")
    caddy_apex = optional(string, "")
    frpc       = optional(string, "")
  }))
  default = []
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
