locals {
  sabnzbd_ports = {
    webui = 8080
  }
}

resource "incus_storage_volume" "sabnzbd_data" {
  name = "sabnzbd-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "sabnzbd" {
  name = "sabnzbd"
  type = "container"

  target   = var.target
  profiles = ["default"]
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

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = "10:66:6a:fb:50:7e"
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

output "backups" {
  value = {
    sabnzbd = {
      volumes = {
        (incus_storage_volume.sabnzbd_data.name) = {
          excludes = ["history", "*.bak"]
        }
      }
    }
  }
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
