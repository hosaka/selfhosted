variable "timezone" {
  type = string
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

# Credentials for each module, see secrets.auto.tfvars (age encrypted as secrets.auto.tfvars.age).
variable "secrets" {
  type = map(any)
}

# LLDAP users by username, see users/variables.tf. Set in secrets.auto.tfvars next to `secrets`.
variable "users" {
  type    = any
  default = {}
}

variable "cluster" {
  type = object({
    name = optional(string, "cluster")

    uplink  = string
    gateway = string

    node-1 = object({
      target = optional(string, "node-1")
    })
    node-2 = object({
      target = optional(string, "node-2")
    })
    node-3 = object({
      target = optional(string, "node-3")
    })
    node-4 = object({
      target = optional(string, "node-4")
    })
  })

  validation {
    condition = alltrue([
      for v in [var.cluster.name, var.cluster.uplink, var.cluster.node-1.target, var.cluster.node-2.target, var.cluster.node-3.target, var.cluster.node-4.target] :
      trimspace(v) != ""
    ])
    error_message = "Cluster name, uplink and node targets must not be empty."
  }

  validation {
    condition = length(distinct([
      var.cluster.node-1.target,
      var.cluster.node-2.target,
      var.cluster.node-3.target,
      var.cluster.node-4.target,
    ])) == 4
    error_message = "Each cluster node must have a distinct target."
  }
}

# OVN network addresses, see environment.auto.tfvars.
variable "ovn" {
  type = object({
    subnet          = string
    dhcp_range      = string
    router          = string
    central         = map(string)
    gateway_chassis = list(string)
  })

  validation {
    condition     = length(var.ovn.central) % 2 == 1
    error_message = "The OVN central database needs an odd number of members, raft needs a majority to agree."
  }

  validation {
    condition = alltrue([
      for address in concat([var.ovn.router], values(var.ovn.central)) : cidrcontains(var.cluster.gateway, address)
    ]) && length(distinct(concat([var.ovn.router], values(var.ovn.central)))) == length(var.ovn.central) + 1
    error_message = "The OVN router and central addresses must be distinct addresses on the LAN."
  }

  validation {
    condition     = alltrue([for address in split("-", var.ovn.dhcp_range) : cidrcontains(var.ovn.subnet, address)])
    error_message = "The OVN DHCP range must be inside the OVN subnet."
  }

  validation {
    condition     = !cidrcontains(var.ovn.subnet, cidrhost(var.cluster.gateway, 0)) && !cidrcontains(var.cluster.gateway, cidrhost(var.ovn.subnet, 0))
    error_message = "The OVN subnet must not overlap the LAN."
  }
}

# UPS monitor, see environment.auto.tfvars.
variable "ups" {
  type = object({
    address     = string
    secondaries = optional(map(string), {})
  })

  validation {
    condition     = cidrcontains(var.cluster.gateway, var.ups.address) && !contains(concat([var.ovn.router], values(var.ovn.central)), var.ups.address)
    error_message = "The UPS monitor's address must be on the LAN and not one of the OVN addresses."
  }

  validation {
    condition     = alltrue([for address in values(var.ups.secondaries) : cidrcontains(var.cluster.gateway, address)])
    error_message = "NUT secondaries must be on the LAN, where the UPS monitor can reach them."
  }
}

# Fixed OVN addresses per module and NIC, see addresses.auto.tfvars.
variable "addresses" {
  type = map(map(object({
    hwaddr = string
    ipv4   = string
  })))

  validation {
    condition = (
      length(flatten([for m in values(var.addresses) : values(m)])) ==
      length(distinct(flatten([for m in values(var.addresses) : [for a in values(m) : a.ipv4]])))
    )
    error_message = "An OVN address is assigned more than once."
  }

  validation {
    condition = (
      length(flatten([for m in values(var.addresses) : values(m)])) ==
      length(distinct(flatten([for m in values(var.addresses) : [for a in values(m) : lower(a.hwaddr)]])))
    )
    error_message = "A MAC address is assigned more than once."
  }

  validation {
    condition = alltrue(flatten([
      for m in values(var.addresses) : [
        for a in values(m) : cidrcontains(var.ovn.subnet, a.ipv4) && a.ipv4 != cidrhost(var.ovn.subnet, 1)
      ]
    ]))
    error_message = "OVN addresses must be inside the OVN subnet and not the router's."
  }
}

# Container image versions for each module, see versions.auto.tfvars.
variable "versions" {
  type = map(map(string))
}
