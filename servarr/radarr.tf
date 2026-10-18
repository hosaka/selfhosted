locals {
  radarr_ports = {
    webui = 7878
  }

  radarr_caddy = <<-EOT
  radarr.${var.private_domain} {
  	reverse_proxy ${var.addresses.radarr.ipv4}:${local.radarr_ports.webui}
  }
  EOT
}

resource "incus_storage_volume" "radarr_data" {
  name = "radarr-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "radarr" {
  name = "radarr"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:hotio/radarr:release-${var.versions.radarr}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.radarr_data.pool
      source = incus_storage_volume.radarr_data.name
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
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.radarr.nic
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.RADARR__AUTH__APIKEY" = sensitive(var.secrets.radarr_api_key)
    "environment.TZ"                   = var.timezone
  }
}
