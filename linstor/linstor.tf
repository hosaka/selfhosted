locals {
  linstor_controller_ports = {
    api = 3370
  }

  satellite_execs = merge([
    for name, member in var.members : {

      # Register the satellite nodes. They don't have to be immediately reachable.
      "00-register-${name}" = {
        command = [
          "linstor", "node", "create",
          name, "${split(":", trimprefix(member.address, "https://"))[0]}",
          "--node-type", "satellite"
        ]
        trigger = "once"
      }
    }
  ]...)
}

# A Linstor controller instance. It is responsible for orchestrating the sattelite nodes.
resource "incus_instance" "linstor_controller" {
  name = "linstor-controller"
  type = "container"

  target  = var.target
  image   = "images:debian/trixie/cloud"
  project = "internal"

  config = {
    "boot.autostart"            = true
    "boot.autostart.priority"   = 100
    "cloud-init.user-data"      = file("${path.module}/user-data.yml")
    "cloud-init.network-config" = file("${path.module}/network-config.yml")

    # Instructs which interface should be used for IP reporting. LAN in this case.
    "user.access_interface" = "eth1"
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      "network" = "lan"
      "hwaddr"  = "10:66:6a:3f:16:7a"
    }
  }

  wait_for {
    type = "cloud-init"
  }

  exec = local.satellite_execs
}

# Configure Incus to be able to communicate with the Linstor controller.
resource "incus_server" "linstor_controller" {
  config = {
    "storage.linstor.controller_connection" = "http://${incus_instance.linstor_controller.ipv4_address}:${local.linstor_controller_ports.api}"
  }
}

resource "null_resource" "post_linstor_controller" {
  depends_on = [
    incus_instance.linstor_controller,
    incus_server.linstor_controller,
  ]
}

# Create the storage pool on Incus using Linstor.
resource "incus_storage_pool" "linstor_per_node" {
  for_each = { for k, v in var.members : k => v }
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
    incus_server.linstor_controller,
  ]
}

resource "incus_storage_pool" "linstor" {
  name        = "linstor"
  driver      = "linstor"
  description = "Replicated storage pool (LINSTOR)"

  config = {
    # The `storage_pool` needs to match the ZFS pool name managed by Incus
    "linstor.resource_group.name"         = "linstor"
    "linstor.resource_group.storage_pool" = "nvme"
    "linstor.resource_group.place_count"  = "3"
  }

  depends_on = [
    incus_storage_pool.linstor_per_node
  ]
}

resource "null_resource" "post_linstor_pool" {
  depends_on = [
    incus_storage_pool.linstor,
  ]
}

resource "null_resource" "post_linstor" {
  depends_on = [
    null_resource.post_linstor_controller,
    null_resource.post_linstor_pool,
  ]
}

output "linstor_ip" {
  description = "Linstor Controller IP address"
  value       = incus_instance.linstor_controller.ipv4_address
}

output "linstor_api_address" {
  description = "Linstor Controller REST API address, it also serves Prometheus metrics on /metrics"
  value       = "${incus_instance.linstor_controller.ipv4_address}:${local.linstor_controller_ports.api}"
}

