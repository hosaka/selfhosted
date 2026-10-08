variable "sabnzbd_version" {
  type    = string
  default = "5.0.4"
}

locals {
  sabnzbd_ports = {
    webui = 8080
  }
}

resource "incus_storage_volume" "sabnzbd_config" {
  name = "sabnzbd-config"
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
  profiles = ["default"]
  image    = "ghcr:hotio/sabnzbd:release-${var.sabnzbd_version}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.sabnzbd_config.pool
      source = incus_storage_volume.sabnzbd_config.name
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
    name = "eth0"
    type = "nic"
    properties = {
      network = "incusbr0"
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      network = "meshbr0"
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
