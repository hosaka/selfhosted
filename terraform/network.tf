resource "incus_network" "lan_pending" {
  for_each = data.incus_cluster.this.members

  name   = "lan"
  type   = "physical"
  target = data.incus_cluster.this.is_clustered ? each.key : null

  config = {
    parent = var.cluster.nic-1
  }
}

resource "incus_network" "lan" {
  name        = "lan"
  type        = "physical"
  description = "Direct local network access (without NAT)"

  depends_on = [incus_network.lan_pending]
}

resource "incus_profile" "lan" {
  name        = "lan"
  description = "Instances that need direct LAN access"

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name    = "eth1"
      network = incus_network.lan.name
    }
  }
}

