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

resource "incus_storage_volume" "lidarr_data" {
  name = "lidarr-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "lidarr" {
  name = "lidarr"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:hotio/lidarr:${var.versions.lidarr}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.lidarr_data.pool
      source = incus_storage_volume.lidarr_data.name
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
      hwaddr         = "10:66:6a:13:0e:c4"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.LIDARR__AUTH__APIKEY" = sensitive(var.secrets.lidarr_api_key)
    "environment.TZ"                   = var.timezone

    "user.access_interface" = "eth1"
  }
}
