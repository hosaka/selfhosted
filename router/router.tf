locals {
  dhcp = templatefile("${path.module}/dhcp.tftpl", {
    cluster         = var.cluster
    public_domain   = var.public_domain
    private_domain  = var.private_domain
    caddy_address   = var.caddy_address
    tessier_address = var.tessier_address
  })

  network = templatefile("${path.module}/network.tftpl", {
    address     = split("/", var.gateway)[0]
    netmask     = cidrnetmask(var.gateway)
    ovn_network = cidrhost(var.ovn.subnet, 0)
    ovn_netmask = cidrnetmask(var.ovn.subnet)
    ovn_router  = var.ovn.router
  })
}

resource "openwrt_configfile" "dhcp" {
  name    = "dhcp"
  content = local.dhcp

  lifecycle {
    prevent_destroy = true
  }
}

resource "openwrt_configfile" "network" {
  name    = "network"
  content = local.network

  lifecycle {
    prevent_destroy = true
  }
}

resource "openwrt_configfile" "firewall" {
  name    = "firewall"
  content = file("${path.module}/firewall")

  lifecycle {
    prevent_destroy = true
  }
}

resource "openwrt_configfile" "stubby" {
  name    = "stubby"
  content = file("${path.module}/stubby")

  lifecycle {
    prevent_destroy = true
  }
}
