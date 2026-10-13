locals {
  sabnzbd_ports = {
    webui = 8080
  }
}

resource "incus_storage_volume" "sabnzbd_data" {
  name = "sabnzbd-data"
  pool = "linstor"

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "sabnzbd" {
  name = "sabnzbd"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:hotio/sabnzbd:release-${var.versions.sabnzbd}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.sabnzbd_data.pool
      source = incus_storage_volume.sabnzbd_data.name
    }
  }

  device {
    name = "media"
    type = "disk"
    properties = {
      path   = "/data/media"
      pool   = var.media_pool
      source = var.media_source
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

output "probes" {
  value = [
    "https://nzb.${var.private_domain}/",
  ]
}

output "ingress" {
  value = {
    name  = "sabnzbd"
    caddy = <<-EOT
    nzb.${var.private_domain} {
      reverse_proxy ${incus_instance.sabnzbd.ipv4_address}:${local.sabnzbd_ports.webui}
    }
    EOT
  }
}
