locals {
  central_ports = {
    northbound = 6641
    southbound = 6642
  }

  central_hwaddrs = {
    "node-1" = "02:3f:6a:2a:ae:9d"
    "node-2" = "02:f9:a4:24:31:c8"
    "node-3" = "02:c2:71:0a:f6:28"
  }

  central_names = { for member in keys(var.central) : member => "ovn-central-${trimprefix(member, "node-")}" }

  # the first member creates the raft clusters, the others join through it
  central_first = keys(var.central)[0]

  northbound = join(",", [for address in values(var.central) : "tcp:${address}:${local.central_ports.northbound}"])
  southbound = join(",", [for address in values(var.central) : "tcp:${address}:${local.central_ports.southbound}"])

  lan_gateway = split("/", var.gateway)[0]
  lan_prefix  = split("/", var.gateway)[1]
}

resource "incus_storage_volume" "ovn_central" {
  for_each = var.central

  name    = "${local.central_names[each.key]}-data"
  pool    = "local"
  project = "internal"
  target  = each.key
}

# OVN central database members
resource "incus_instance" "ovn_central" {
  for_each = var.central

  name    = local.central_names[each.key]
  type    = "container"
  project = "internal"

  target   = each.key
  profiles = ["default"]
  image    = "images:debian/trixie/cloud"

  # directly on the LAN, the OVN network can't depend on itself
  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "lan"
      hwaddr  = local.central_hwaddrs[each.key]
    }
  }

  # the databases, kept when the container is replaced
  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/etc/ovn"
      pool   = incus_storage_volume.ovn_central[each.key].pool
      source = incus_storage_volume.ovn_central[each.key].name
    }
  }

  config = {
    # start before and stop after everything else on the node, instances need it to add and remove their OVN ports
    "boot.autostart"          = true
    "boot.autostart.priority" = 100
    "boot.stop.priority"      = -100

    # static address, so the database comes up without router DHCP
    "cloud-init.network-config" = <<-EOT
      version: 2
      ethernets:
        eth0:
          addresses: [${each.value}/${local.lan_prefix}]
          routes: [{ to: 0.0.0.0/0, via: ${local.lan_gateway} }]
          nameservers: { addresses: [${local.lan_gateway}] }
    EOT
    "cloud-init.user-data" = templatefile("${path.module}/central.yml.tpl", {
      zabbly_key      = chomp(file("${path.module}/zabbly.asc"))
      ovn_version     = var.versions.ovn
      address         = each.value
      first_address   = each.key == local.central_first ? "" : var.central[local.central_first]
      northbound_port = local.central_ports.northbound
      southbound_port = local.central_ports.southbound
      northbound      = local.northbound
      southbound      = local.southbound
    })
  }

  wait_for {
    type = "cloud-init"
  }
}

# Incus creates OVN networks through the northbound database.
# It finds the southbound one through the local chassis.
resource "incus_server" "ovn" {
  config = {
    "network.ovn.northbound_connection" = local.northbound
  }

  depends_on = [null_resource.ovn_chassis]
}
