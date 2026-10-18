locals {
  # every MAC address literal in the configuration plus the OVN ones,
  # instances pin them with hwaddr to keep their IPs across replacements
  pinned_hwaddrs = concat(
    flatten([
      for f in fileset(path.root, "**/*.tf") : [
        for m in regexall("\"((?:[0-9a-f]{2}:){5}[0-9a-f]{2})\"", lower(file("${path.root}/${f}"))) : m[0]
      ] if !startswith(f, ".terraform/")
    ]),
    flatten([for m in values(var.addresses) : [for a in values(m) : lower(a.hwaddr)]]),
  )
  duplicate_hwaddrs = distinct([
    for mac in local.pinned_hwaddrs : mac if length([for m in local.pinned_hwaddrs : m if m == mac]) > 1
  ])

  # fixed OVN addresses per module and instance: the address for templates and the NIC that carries it
  ovn_addresses = {
    for module_name, instances in var.addresses : module_name => {
      for name, address in instances : name => {
        ipv4 = address.ipv4
        nic = {
          name    = "eth0"
          network = module.ovn.network
          hwaddr  = address.hwaddr
          # CIDR form, Incus configures OCI containers statically instead of over DHCP
          "ipv4.address" = "${address.ipv4}/${split("/", var.ovn.subnet)[1]}"
          "ipv4.gateway" = cidrhost(var.ovn.subnet, 1)
        }
      }
    }
  }
}

resource "incus_network" "lan_per_node" {
  for_each = local.founding_members

  name   = "lan"
  type   = "physical"
  target = each.key

  config = {
    parent = var.cluster.uplink
  }

  depends_on = [
    null_resource.post_projects,
  ]
}

resource "incus_network" "lan" {
  name        = "lan"
  type        = "physical"
  description = "Direct local network access (without NAT) and OVN uplink"

  # only used by OVN networks, instances attached to lan directly still get their addresses from the router
  config = {
    "ipv4.gateway"    = var.cluster.gateway
    "dns.nameservers" = split("/", var.cluster.gateway)[0]
    # the OVN router's address on the LAN, the router's static route for the OVN subnet points at it
    "ipv4.ovn.ranges" = "${var.ovn.router}-${var.ovn.router}"
    # OVN subnets that are routed instead of NATed have to be listed here
    "ipv4.routes" = var.ovn.subnet
  }

  depends_on = [
    null_resource.post_projects,
    incus_network.lan_per_node,
  ]

  lifecycle {
    precondition {
      condition     = length(local.duplicate_hwaddrs) == 0
      error_message = "MAC addresses pinned more than once: ${join(", ", local.duplicate_hwaddrs)}"
    }
  }
}

resource "null_resource" "post_networks" {
  depends_on = [
    incus_network.lan,
  ]
}

