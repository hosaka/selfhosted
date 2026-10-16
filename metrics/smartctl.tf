locals {
  smartctl_ports = {
    metrics = 9633
  }

  smartctl_hwaddrs = {
    "node-1" = "10:66:6a:9c:6b:4e"
    "node-2" = "10:66:6a:2c:22:e1"
    "node-3" = "10:66:6a:b1:18:30"
    "node-4" = "10:66:6a:7e:ad:ae"
  }

  smartctl_targets = {
    for name, instance in incus_instance.smartctl_exporter :
    name => "${instance.ipv4_address}:${local.smartctl_ports.metrics}"
  }
}

# Each member runs its own exporter with its drives passed through.
# smartctl needs CAP_SYS_RAWIO in the host namespace for ATA passthrough and CAP_SYS_ADMIN for NVMe admin commands,
# so the container has to be privileged, and incus drops sys_rawio from privileged containers by default.
resource "incus_instance" "smartctl_exporter" {
  for_each = var.smart_devices

  name = "smartctl-exporter-${each.key}"
  type = "container"

  target   = each.key
  profiles = ["default"]
  image    = "docker:prometheuscommunity/smartctl-exporter:v${var.versions.smartctl_exporter}"

  dynamic "device" {
    for_each = toset(each.value)

    content {
      name = basename(device.value)
      type = "unix-block"
      properties = {
        source = device.value
        path   = device.value
      }
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = local.smartctl_hwaddrs[each.key]
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "security.privileged" = "true"
    "raw.lxc"             = <<-EOT
      lxc.cap.drop =
      lxc.cap.drop = sys_time sys_module mac_admin mac_override
    EOT

    # the image runs as nobody, but the passthrough ioctls need root
    "oci.uid" = "0"
    "oci.gid" = "0"

    # by-id names don't tell smartctl the device type, so pass it explicitly
    "oci.entrypoint" = join(" ", concat(
      ["/bin/smartctl_exporter"],
      [for device in each.value : "--smartctl.device=${device};${startswith(basename(device), "nvme-") ? "nvme" : "sat"}"],
    ))

    "user.access_interface" = "eth1"
  }
}
