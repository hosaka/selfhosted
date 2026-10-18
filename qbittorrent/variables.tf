variable "vpn_provider" {
  type    = string
  default = "proton"
}

variable "secrets" {
  type = object({
    wg0_conf = string
  })
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

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}

# LAN prefix, kept out of the VPN tunnel so Caddy and the nodes get replies
variable "lan_network" {
  type = string
}
