variable "vpn_provider" {
  type = string
}

variable "vpn_lan_network" {
  type = string
}

variable "secrets" {
  type = object({
    wg0_conf = string
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

variable "versions" {
  type = object({
    qbittorrent = string
    qbitmanage  = string
  })
}
