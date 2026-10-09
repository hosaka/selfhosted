resource "incus_network" "incusbr0_per_node" {
  for_each = local.members

  name   = "incusbr0"
  target = each.key
  type   = "bridge"

  config = {
  }

  depends_on = [
    null_resource.post_projects,
  ]
}

resource "incus_network" "incusbr0" {
  name        = "incusbr0"
  description = "Local network bridge (NAT)"

  config = {
  }

  depends_on = [
    null_resource.post_projects,
    incus_network.incusbr0_per_node,
  ]
}

locals {
  memberUplinkInterface = {
    (var.cluster.node-1.target) = var.cluster.uplink
    (var.cluster.node-2.target) = var.cluster.uplink
    (var.cluster.node-3.target) = var.cluster.uplink
    # node-4 may differ - keep the map structure for that reason
  }

  # meshbr0 subnet, passed to services that need to trust or bypass mesh traffic
  mesh_cidr = format("10.%d.%d.0/24", random_integer.meshbr0-v4-subnet-2.result, random_integer.meshbr0-v4-subnet-3.result)
}

// Generate random values for the meshbr0 IPv4 subnet.
resource "random_integer" "meshbr0-v4-subnet-2" {
  min = 100
  max = 255
}
resource "random_integer" "meshbr0-v4-subnet-3" {
  min = 0
  max = 255
}

// Generate random values for the meshbr0 IPv6 subnet.
resource "random_integer" "meshbr0-v6-subnet-2" {
  min = 0
  max = 65535
}
resource "random_integer" "meshbr0-v6-subnet-3" {
  min = 0
  max = 65535
}
resource "random_integer" "meshbr0-v6-subnet-4" {
  min = 0
  max = 65535
}

resource "incus_network" "meshbr0_per_node" {
  for_each = local.members

  name   = "meshbr0"
  target = each.key
  type   = "bridge"

  config = {
    "tunnel.mesh.interface" = local.memberUplinkInterface[each.key]
  }

  depends_on = [
    null_resource.post_projects,
  ]
}

resource "incus_network" "meshbr0" {
  name        = "meshbr0"
  description = "Internal mesh network bridge"

  config = {
    "ipv4.address" = "${cidrhost(local.mesh_cidr, 1)}/24"
    "ipv4.nat"     = "false"
    "ipv6.address" = "none"
    # "ipv6.address"         = format("fd42:%x:%x:%x::/64", random_integer.meshbr0-v6-subnet-2.result, random_integer.meshbr0-v6-subnet-3.result, random_integer.meshbr0-v6-subnet-4.result)
    # "ipv6.nat"             = "true"
    "tunnel.mesh.id"       = "1000"
    "tunnel.mesh.protocol" = "vxlan"
  }

  depends_on = [
    null_resource.post_projects,
    incus_network.meshbr0_per_node,
  ]
}

resource "incus_network" "lan_per_node" {
  for_each = local.members

  name   = "lan"
  type   = "physical"
  target = each.key

  config = {
    parent = local.memberUplinkInterface[each.key]
  }

  depends_on = [
    null_resource.post_projects,
  ]
}

resource "incus_network" "lan" {
  name        = "lan"
  type        = "physical"
  description = "Direct local network access (without NAT)"

  depends_on = [
    null_resource.post_projects,
    incus_network.lan_per_node,
  ]
}

resource "null_resource" "post_networks" {
  depends_on = [
    incus_network.incusbr0,
    incus_network.meshbr0,
    incus_network.lan,
  ]
}

