variable "lidarr_version" {
  type    = string
  default = "pr-plugins-3.1.2.4913"
}

locals {
  lidarr_ports = {
    webui = 8686
  }

  lidarr_caddy = <<-EOT
		lidarr.${var.private_domain} {
			reverse_proxy ${incus_instance.lidarr.ipv4_address}:${local.lidarr_ports.webui}
		}
  EOT
}

resource "incus_storage_volume" "lidarr_config" {
  name = "lidarr-config"
  pool = "linstor"

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "lidarr" {
  name = "lidarr"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:hotio/lidarr:${var.lidarr_version}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.lidarr_config.pool
      source = incus_storage_volume.lidarr_config.name
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
    "environment.LIDARR__AUTH__APIKEY" = sensitive(var.config.lidarr_api_key)
    "environment.TZ"                   = var.timezone

    "user.access_interface" = "eth1"
  }
}
