variable "config" {
  type = object({
    vpn_provider    = string
    vpn_lan_network = string
    wg0_conf        = string
  })
}

variable "target" {
  type = string
}

variable "timezone" {
  type    = string
  default = "UTC"
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
