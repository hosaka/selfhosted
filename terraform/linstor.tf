resource "incus_instance" "linstor" {
  name     = "linstor"
  type     = "container"
  target   = var.cluster.node-1
  image    = "images:debian/trixie/cloud"
  profiles = ["default", incus_profile.lan.name]

  config = {
    "cloud-init.user-data" = templatefile("${path.module}/cloud-init/linstor.user-data.yml", {
      ssh_key = trimspace(file("~/.ssh/id_ed25519.pub"))
    })
    "cloud-init.network-config" = templatefile("${path.module}/cloud-init/linstor.network-config.yml", {
      ipv4 = "10.10.1.10/24"
      gateway = "10.10.1.1"
    })
  }
}

resource "incus_server" "linstor_controller" {
  config = {
    "storage.linstor.controller_connection" = "http://10.10.1.10:3370"
  }
}

resource "incus_storage_pool" "remote_pending" {
  for_each = data.incus_cluster.this.members
  name     = "remote"
  driver   = "linstor"
  target = data.incus_cluster.this.is_clustered ? each.key : null

  depends_on = [incus_server.linstor_controller]
}

resource "incus_storage_pool" "remote" {
  name   = "remote"
  driver = "linstor"
  description = "Remote storage pool (LINSTOR)"

  config = {
    "linstor.resource_group.name" = "remote"
    "linstor.resource_group.storage_pool" = "nvme_pool"
    "linstor.resource_group.place_count"  = "2"
  }

  depends_on = [incus_storage_pool.remote_pending]
}
