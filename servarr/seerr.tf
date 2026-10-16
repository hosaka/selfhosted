locals {
  seerr_ports = {
    webui = 5055
  }

  seerr_caddy = <<-EOT
  seerr.${var.private_domain} {
  	reverse_proxy ${incus_instance.seerr.ipv4_address}:${local.seerr_ports.webui}
  }
  EOT
}

resource "incus_storage_volume" "seerr_data" {
  name = "seerr-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "seerr" {
  name = "seerr"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:hotio/seerr:release-${var.versions.seerr}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.seerr_data.pool
      source = incus_storage_volume.seerr_data.name
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = "10:66:6a:ac:03:83"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.TZ" = var.timezone

    "user.access_interface" = "eth1"
  }
}
