variable "target" {
  type = string
}

# LAN address of the container, without a prefix length
variable "address" {
  type = string
}

# LAN router with its prefix length, e.g. 10.10.0.1/24
variable "gateway" {
  type = string
}

# Incus API of the target member, as https://<address>:<port>
variable "cluster_address" {
  type = string
}

# The cluster's server certificate, cluster-poweroff checks every member's API against it
variable "cluster_certificate" {
  type = string
}

variable "private_domain" {
  type = string
}

variable "versions" {
  type = object({
    peanut = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}

# The UPS's USB vendor and product id, 4 hex digits each
variable "usb" {
  type = object({
    vendorid  = string
    productid = string
  })
}
