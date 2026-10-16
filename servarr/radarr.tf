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
  profiles = ["default"]
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
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = "10:66:6a:ff:6e:9b"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.RADARR__AUTH__APIKEY" = sensitive(var.secrets.radarr_api_key)
    "environment.TZ"                   = var.timezone

    "user.access_interface" = "eth1"
  }
}
