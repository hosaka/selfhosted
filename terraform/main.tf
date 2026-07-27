data "incus_cluster" "this" {
  remote = var.cluster.name
  lifecycle {
    postcondition {
      condition     = alltrue(self.is_clustered ? [for i, v in self.members : v.status == "Online"] : [])
      error_message = "All servers must be online."
    }
  }
}

resource "incus_network" "lan_pending" {
  for_each = data.incus_cluster.this.members

  name   = "lan"
  type   = "physical"
  target = data.incus_cluster.this.is_clustered ? each.key : null

  config = {
    parent = "eno1"
  }
}

resource "incus_network" "lan" {
  name = "lan"
  type = "physical"
  description = "Services accessible on LAN"

  depends_on = [incus_network.lan_pending]
}

resource "incus_profile" "default" {
  name        = "default"
  description = "Default Incus profile"

  config = {
    "limits.cpu"         = "1"
    "limits.memory"      = "512MiB"
    # "snapshots.schedule" = "@daily"
    # "snapshots.expiry"   = "7d"
  }

  device {
    name = "eth0"
    properties = {
      nictype = "bridged"
      parent  = "incusbr0"
    }
    type = "nic"
  }

  device {
    name = "root"
    properties = {
      path = "/"
      pool = "local"
    }
    type = "disk"
  }
}

resource "incus_profile" "lan" {
  name = "lan"

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name    = "eth1"
      network = incus_network.lan.name
    }
  }
}

# resource "incus_instance" "ingress" {
#   name     = "ingress"
#   type     = "container"
#   image    = "images:debian/trixie/cloud"
#   profiles = ["default", incus_profile.base.name]
# }

