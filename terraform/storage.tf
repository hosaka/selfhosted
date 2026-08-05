locals {
  target = var.cluster.node-1.target

  nodes = {
    (var.cluster.node-1.target) = var.cluster.node-1
    (var.cluster.node-2.target) = var.cluster.node-2
    (var.cluster.node-3.target) = var.cluster.node-3
  }

  cache_nodes = {
    for k, v in data.incus_cluster.this.members : k => v
    if k != var.cluster.bootstrap
  }

  satellite_execs = merge([
    for name, member in data.incus_cluster.this.members : {

      # Register the satellite nodes to the LINSTOR cluster.
      "00-register-${name}" = {
        command = [
          "linstor", "node", "create",
          name, local.nodes[name].ipv4_address,
          "--node-type", "satellite"
        ]
        trigger = "once"
      }

      # Create the storage pools in each satellite node that will contribute storage
      # to the cluster. Since nvme-1 is taken up by IncusOS and local storage we will
      # use the spare nvme-2.

      # Creating nvme_pool this way will result in an unencrypted ZFS pool in IncusOS
      # which will be not managed by it and will result in it being discarded during 
      # an update, see:

      # Instead ZFS pools should be created using `incus admin os system storage edit`
      # for each node, adding required disks to the pool first, then in linstror OCI
      # add them with `linstor storage-pool create zfsthin node-N nvme_pool nvme_pool`

      # todo: automate the above, require creating the nvme_pool first, the rest can
      # be done with an exec command here

      # "01-pool-${name}" = {
      #   command = [
      #     "linstor", "physical-storage", "create-device-pool",
      #     "--storage-pool", "nvme_pool", "--pool-name", "nvme_pool",
      #     "zfsthin", name, local.nodes[name].nvme-2
      #   ]
      #   trigger = "once"
      # }

    }
  ]...)
}

# Each node should have it's own cache storage but only the bootstrap node gets this
# by default because the IncusOS image is created with "Apply default configuration".
# The other nodes in the cluster need manual configuration.

resource "incus_storage_volume" "images" {
  for_each    = local.cache_nodes
  name        = "images"
  description = "Volume holding system images"
  pool        = "local"
  target      = each.key
}

resource "incus_storage_volume" "backups" {
  for_each    = local.cache_nodes
  name        = "backups"
  description = "Volume holding system backups"
  pool        = "local"
  target      = each.key
}

resource "incus_storage_volume" "logs" {
  for_each = local.cache_nodes
  name     = "logs"
  pool     = "local"
  target   = each.key
}

resource "incus_server" "storage_volumes" {
  for_each = data.incus_cluster.this.members

  target = data.incus_cluster.this.is_clustered ? each.key : null

  config = {
    "storage.images_volume"  = "local/images"
    "storage.backups_volume" = "local/backups"
    "storage.logs_volume"    = "local/logs"
  }

  depends_on = [incus_storage_volume.images, incus_storage_volume.backups, incus_storage_volume.logs]
}

# A LINSTOR controller instance that is pinned to the first node in the cluster and
# uses local storage. It is responsible for orchestrating the sattelite nodes.
resource "incus_instance" "linstor" {
  name = "linstor"
  type = "container"

  target   = local.target
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
  depends_on = [incus_server.storage_volumes, incus_instance.linstor]

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

