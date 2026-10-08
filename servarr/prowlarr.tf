variable "prowlarr_version" {
  type    = string
  default = "2.5.2.5491"
}

locals {
  prowlarr_ports = {
    webui = 9696
  }

  prowlarr_caddy = <<-EOT
		prowlarr.${var.private_domain} {
			reverse_proxy ${incus_instance.prowlarr.ipv4_address}:${local.prowlarr_ports.webui}
		}
  EOT
}

resource "incus_storage_volume" "prowlarr_config" {
  name = "prowlarr-config"
  pool = "linstor"

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "prowlarr" {
  name = "prowlarr"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:hotio/prowlarr:release-${var.prowlarr_version}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.prowlarr_config.pool
      source = incus_storage_volume.prowlarr_config.name
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
    "environment.PROWLARR__AUTH__APIKEY" = sensitive(var.config.prowlarr_api_key)
    "environment.TZ"                     = var.timezone

    "user.access_interface" = "eth1"
  }
}
