locals {
  dhcp = templatefile("${path.module}/dhcp.tpl", {
    cluster         = var.cluster
    public_domain   = var.public_domain
    private_domain  = var.private_domain
    caddy_address   = var.caddy_address
    tessier_address = var.tessier_address
  })

  network = templatefile("${path.module}/network.tpl", {
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
  content = templatefile("${path.module}/firewall.tpl", {})

  lifecycle {
    prevent_destroy = true
  }
}
