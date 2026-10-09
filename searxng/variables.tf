variable "trusted_proxies" {
  type = string
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
  })
}
