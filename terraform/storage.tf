locals {
  satellite_execs = merge([
    for name, member in data.incus_cluster.this.members : {

      # Register the satellite nodes to the LINSTOR cluster.
      "00-register-${name}" = {
        command = [
          "linstor", "node", "create",
          name, split(":", trimprefix(member.address, "https://"))[0],
          "--node-type", "satellite"
        ]
        trigger = "once"
      }

      # Create the storage pools in each satellite node that will contribute storage
      # to the cluster. Since nvme-1 is taken up by IncusOS and local storage we will
      # use the spare nvme-2.
      "01-pool-${name}" = {
        command = [
          "linstor", "physical-storage", "create-device-pool",
          "--storage-pool", "nvme_pool", "--pool-name", "nvme_pool",
          "zfsthin", name, var.cluster.nvme-2
        ]
        trigger = "once"
      }

    }
  ]...)
}

# A LINSTOR controller instance that is pinned to the first node in the cluster and
# uses local storage. It is responsible for orchestrating the sattelite nodes.
resource "incus_instance" "linstor" {
  name     = "linstor"
  type     = "container"
  target   = var.cluster.node-1.target
  image    = "images:debian/trixie/cloud"
  profiles = [incus_profile.default.name, incus_profile.lan.name]

  config = {
    "cloud-init.user-data" = templatefile("${path.module}/linstor/user-data.yml.tpl", {
      ssh_key    = trimspace(file("~/.ssh/id_ed25519.pub"))
      linbit_key = indent(10, "\n${file("${path.module}/linstor/package-signing-pubkey.asc")}")
    })
    "cloud-init.network-config" = templatefile("${path.module}/linstor/network-config.yml.tpl", {
      ipv4    = "${var.services.linstor.ipv4}/24"
      gateway = var.services.gateway
    })
  }

  wait_for {
    type = "cloud-init"
  }

  exec = local.satellite_execs
}

# Configure Incus to be able to communicate with the LINSTOR controller.
resource "incus_server" "linstor_controller" {
  depends_on = [incus_instance.linstor]

  config = {
    "storage.linstor.controller_connection" = "http://${var.services.linstor.ipv4}:3370"
  }
}

# Create the storage pool on Incus. We’ll specify the `linstor.resource_group.storage_pool`
# option to ensure that LINSTOR uses the nvme_pool storage pool for the volumes on this
# Incus storage pool.
resource "incus_storage_pool" "remote_pending" {
  depends_on = [incus_server.linstor_controller]

  for_each = data.incus_cluster.this.members
  name     = "remote"
  driver   = "linstor"
  target   = data.incus_cluster.this.is_clustered ? each.key : null
}

resource "incus_storage_pool" "remote" {
  depends_on = [incus_storage_pool.remote_pending]

  name        = "remote"
  driver      = "linstor"
  description = "Remote storage pool (LINSTOR)"

  config = {
    "linstor.resource_group.name"         = "remote"
    "linstor.resource_group.storage_pool" = "nvme_pool"
    "linstor.resource_group.place_count"  = "2"
  }
}

# Use this profile for instances that need to be stored in a replicated LINSTOR pool.
resource "incus_profile" "replicated" {
  name        = "replicated"
  description = "Instances that use replicated storage"

  device {
    name = "root"
    properties = {
      path = "/"
      pool = incus_storage_pool.remote.name
    }
    type = "disk"
  }
}

