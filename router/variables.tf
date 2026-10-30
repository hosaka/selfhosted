# LAN address of the router with its prefix length, e.g. 10.10.0.1/24
variable "gateway" {
  type = string
}

# Every member gets a static lease and a DNS record, the cluster name resolves to node-1
variable "cluster" {
  type = object({
    name = string
    node-1 = object({
      target       = string
      ipv4_address = string
    })
    node-2 = object({
      target       = string
      ipv4_address = string
    })
    node-3 = object({
      target       = string
      ipv4_address = string
    })
    node-4 = object({
      target       = string
      ipv4_address = string
    })
  })
}

# The OVN subnet is routed to the OVN router's LAN address
variable "ovn" {
  type = object({
    subnet = string
    router = string
  })
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

# Caddy's address, the private domain and cloud.<public domain> resolve to it on the LAN
variable "caddy_address" {
  type = string
}

# tessier's LAN address, for its static lease and eth.<public domain>
variable "tessier_address" {
  type = string
}
