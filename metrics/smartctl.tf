locals {
  smartctl_ports = {
    metrics = 9633
  }


  smartctl_targets = {
    for node in keys(var.smart_devices) :
    node => "${var.addresses["smartctl-exporter-${node}"].ipv4}:${local.smartctl_ports.metrics}"
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
  profiles = ["default", "oci"]
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
    name       = "eth0"
    type       = "nic"
    properties = var.addresses["smartctl-exporter-${each.key}"].nic
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
  }
}
