variable "trusted_proxies" {
  type = list(string)
}

variable "secrets" {
  type = object({
    secret = string
  })
}

variable "target" {
  type = string
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

variable "versions" {
  type = object({
    searxng = string
    cache   = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
