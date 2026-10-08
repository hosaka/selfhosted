variable "config" {
  type = object({
    secret          = string
    trusted_proxies = string
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
