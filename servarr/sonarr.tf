variable "sonarr_version" {
  type    = string
  default = "4.0.19.2979"
}

locals {
  sonarr_ports = {
    webui = 8989
  }

  sonarr_caddy = <<-EOT
		sonarr.${var.private_domain} {
			reverse_proxy ${incus_instance.sonarr.ipv4_address}:${local.sonarr_ports.webui}
		}
  EOT
}

resource "incus_storage_volume" "sonarr_config" {
  name = "sonarr-config"
  pool = "linstor"

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "sonarr" {
  name = "sonarr"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:hotio/sonarr:release-${var.sonarr_version}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.sonarr_config.pool
      source = incus_storage_volume.sonarr_config.name
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
    "environment.SONARR__AUTH__APIKEY" = sensitive(var.config.sonarr_api_key)
    "environment.TZ"                   = var.timezone

    "user.access_interface" = "eth1"
  }
}
