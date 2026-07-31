variable "config" {
  type = object({
    slsk_username       = string
    slsk_password       = string
    slsk_proxy_username = string
    slsk_proxy_password = string
    umask               = optional(string, "002")
  })
}
variable "target" {
  type = string
}

variable "storage" {
  type    = string
  default = "local"
}

variable "profiles" {
  type = list(string)
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "public_domain" {
  type = string
}

