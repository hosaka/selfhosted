variable "config" {
  type = object({
    slsk_username       = string
    slsk_password       = string
    slsk_proxy_username = string
    slsk_proxy_password = string
    puid                = optional(string, "1000")
    pgid                = optional(string, "1000")
    umask               = optional(string, "002")
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

variable "media_pool" {
  type = string
}

variable "media_source" {
  type = string
}
