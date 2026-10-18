# The instance network: a logical switch for the subnet and a logical router as its gateway.
resource "incus_network" "ovn" {
  name        = "ovn"
  type        = "ovn"
  description = "Cluster network for services, routed to the LAN"

  config = {
    network            = var.uplink
    "ipv4.address"     = "${cidrhost(var.subnet, 1)}/${split("/", var.subnet)[1]}"
    "ipv4.nat"         = "false"
    "ipv4.dhcp.ranges" = var.dhcp_range
    "ipv6.address"     = "none"
    # flood multicast like a plain switch, OVN's snooping needs a querier address Incus doesn't set
    "bridge.multicast_snooping" = "false"
  }

  depends_on = [
    incus_server.ovn,
    null_resource.ovn_gateway,
  ]
}
