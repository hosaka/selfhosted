locals {
  members = {
    "incus-1" = "ens18"
    "incus-2" = "ens18"
    "incus-3" = "ens18"
  }
}

resource "incus_network" "lan_pending" {
  for_each = local.members

  name   = "lan"
  type   = "physical"
  target = each.key

  config = {
    parent = each.value
  }
}

resource "incus_network" "lan" {
  name = "lan"
  type = "physical"

  depends_on = [incus_network.lan_pending]
}

resource "incus_profile" "base" {
  name = "base"

  config = {
    "limits.cpu"         = "1"
    # "limits.memory"      = "512MiB"
    # "snapshots.schedule" = "@daily"
    # "snapshots.expiry"   = "7d"
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      name    = "eth0"
      network = incus_network.lan.name
    }
  }

  # device {
  #   name = "root"
  #   type = "disk"
  #   properties = {
  #     pool = "local"
  #     path = "/"
  #   }
  # }
}

resource "incus_instance" "linstor" {
  name     = "linstor"
  type     = "container"
  target   = "incus-1"
  image    = "images:debian/trixie/cloud"
  profiles = ["default", incus_profile.base.name]

  config = {
    "cloud-init.user-data" = templatefile("${path.module}/cloud-init/linstor.yml", {
      ssh_key = trimspace(file("~/.ssh/id_ed25519.pub"))
    })
  }
}

# resource "incus_instance" "ingress" {
#   name     = "ingress"
#   type     = "container"
#   image    = "images:debian/trixie/cloud"
#   profiles = ["default", incus_profile.base.name]
# }

