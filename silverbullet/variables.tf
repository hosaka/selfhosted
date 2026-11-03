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

# path of the public space on the public domain, as bound in the SilverBullet dashboard
variable "public_prefix" {
  type = string

  validation {
    condition     = can(regex("^/[a-z0-9-]+$", var.public_prefix))
    error_message = "The public prefix must look like /name, without a trailing slash."
  }
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
