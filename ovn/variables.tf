# Package versions, see versions.auto.tfvars
variable "versions" {
  type = map(string)
}

# LAN address of each central database member, keyed by the cluster member it runs on
variable "central" {
  type = map(string)
}

# Cluster members, each one becomes an OVN chassis
variable "members" {
  type = map(any)
}

# Services seed per member, its ovn section has to match the chassis config
variable "seeds" {
  type = map(any)
}

# Members that can host the OVN routers' LAN side
variable "gateway_chassis" {
  type = list(string)
}

# Physical network the OVN router reaches the LAN through
variable "uplink" {
  type = string
}

# OVN network subnet, its first address is the router
variable "subnet" {
  type = string
}

# Addresses OVN hands out to instances without a fixed one
variable "dhcp_range" {
  type = string
}

# LAN router with its prefix length, e.g. 10.10.0.1/24
variable "gateway" {
  type = string
}
