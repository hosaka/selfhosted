variable "radarr_version" {
  type    = string
  default = "6.3.0.10514"
}

locals {
  radarr_ports = {
    webui = 7878
  }

  radarr_caddy = <<-EOT
		radarr.${var.private_domain} {
			reverse_proxy ${incus_instance.radarr.ipv4_address}:${local.radarr_ports.webui}
		}
  EOT
}

resource "incus_storage_volume" "radarr_config" {
  name = "radarr-config"
  pool = "linstor"

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "radarr" {
  name = "radarr"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:hotio/radarr:release-${var.radarr_version}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.radarr_config.pool
      source = incus_storage_volume.radarr_config.name
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
    "environment.RADARR__AUTH__APIKEY" = sensitive(var.config.radarr_api_key)
    "environment.TZ"                   = var.timezone

    "user.access_interface" = "eth1"
  }
}
