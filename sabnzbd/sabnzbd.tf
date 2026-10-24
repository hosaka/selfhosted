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
  profiles = ["default", "oci"]
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
    name = "incomplete"
    type = "disk"
    properties = {
      path   = "/data/incomplete"
      pool   = var.incomplete_pool
      source = var.incomplete_source
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.sabnzbd.nic
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.TZ" = var.timezone
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
      reverse_proxy ${var.addresses.sabnzbd.ipv4}:${local.sabnzbd_ports.webui}
    }
    EOT
  }
}
