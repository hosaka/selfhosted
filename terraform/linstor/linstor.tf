locals {
  satellite_execs = merge([
    for name, member in var.config.members : {

      # Register the satellite nodes to the LINSTOR cluster.
      "00-register-${name}" = {
        command = [
          "linstor", "node", "create",
          name, "${split(":", trimprefix(member.address, "https://"))[0]}",
          "--node-type", "satellite"
        ]
        trigger = "once"
      }

      # Create the storage pools in each satellite node that will contribute storage to the cluster.
      # todo: figure out how to seed an IncusOS image with linstor service enabled, like OC does

      # 0. Make sure that the cluster has incus-linstor app installed and enabled:
      #    incus admin os service edit linstor --target node-n
      #
      # 1. Create a ZFS pool that will be used by linstor (encrypted):
      #    incus admin os system storage storage edit --target node-n
      #
      # config:
      #   pools:
      #     - name: nvme
      #       type: zfs-raid0
      #       devices:
      #       - /dev/disk/by-id/<disk-id-to-be-used-by-incus>
      #
      # 2. Create a ZFS volume on that pool for use with linstor (unencrypted):
      #    incus admin os system storage create-volume -d '{"pool":"nvme","name":"linstor","use":"linstor"}' --target node-n
      #
      # 3. Deploy this linstor module:
      #    just up linstor
      #
      # 4. Inside the incus controller run the following to create a storage pool:
      #    linstor storage-pool create zfsthin node-n nvme nvme/linstor
      #
      # 5. Reboot all nodes in the cluster in order for linstor driver to appear (might not be necessary)
      #
      # 6. Create Incus storage pool backed by the linstor driver

      # todo: Automate the above proccess somehow...
      # "01-pool-${name}" = {
      #   command = [
      #     "linstor", "storage-pool", "create", "zfsthin", name, "nvme", "nvme/linstor"
      #   ]
      #   trigger = "once"
      # }

      # - See: https://github.com/lxc/incus-os/issues/1258#issuecomment-5193553992
      # - See: https://linuxcontainers.org/incus-os/docs/main/reference/system/storage/#managing-volumes
    }
  ]...)
}

# A LINSTOR controller instance that is pinned to the first node in the cluster and
# uses local storage. It is responsible for orchestrating the sattelite nodes.
resource "incus_instance" "linstor" {
  name = "linstor"
  type = "container"

  target  = var.target
  image   = "images:debian/trixie/cloud"
  project = "internal"

  config = {
    "boot.autostart"          = true
    "boot.autostart.priority" = 10

    # Instructs which interface should be used for IP reporting. LAN in this case.
    "user.access_interface" = "eth1"

    "cloud-init.user-data" = templatefile("${path.module}/user-data.yml.tpl", {
      linbit_key = indent(6, trimspace(file("${path.module}/package-signing-pubkey.asc")))
    })
    # "cloud-init.network-config" = templatefile("${path.module}/linstor/network-config.yml.tpl", {
    #   ipv4    = "${var.services.linstor.ipv4}/24"
    #   gateway = var.services.gateway
    # })
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      "network" = "lan"
    }
  }

  wait_for {
    type = "cloud-init"
  }

  exec = local.satellite_execs
}

# Configure Incus to be able to communicate with the LINSTOR controller.
resource "incus_server" "linstor_controller" {
  config = {
    "storage.linstor.controller_connection" = "http://${incus_instance.linstor.ipv4_address}:3370"
  }
}

# Create the storage pool on Incus. We’ll specify the `linstor.resource_group.storage_pool`
# option to ensure that LINSTOR uses the nvme_pool storage pool for the volumes on this
# Incus storage pool.
resource "incus_storage_pool" "linstor_per_node" {
  for_each = { for k, v in var.config.members : k => v }
  name     = "linstor"
  driver   = "linstor"
  target   = each.key

  config = {
    "source" = "linstor"
  }

  lifecycle {
    ignore_changes = [
      # Incus changes the source behind the scenes so we ignore these changes.
      config["source"],
    ]
  }

  depends_on = [
    incus_server.linstor_controller
  ]
}

resource "incus_storage_pool" "linstor" {
  name        = "linstor"
  driver      = "linstor"
  description = "Replicated storage pool (LINSTOR)"

  config = {
    "linstor.resource_group.storage_pool" = "linstor"
    "linstor.resource_group.place_count"  = "3"
  }

  depends_on = [
    incus_storage_pool.linstor_per_node
  ]
}

resource "null_resource" "post_linstor" {
  depends_on = [
    incus_storage_pool.linstor,
  ]
}
