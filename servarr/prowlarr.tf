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

resource "incus_storage_volume" "prowlarr_data" {
  name = "prowlarr-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "prowlarr" {
  name = "prowlarr"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:hotio/prowlarr:release-${var.versions.prowlarr}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.prowlarr_data.pool
      source = incus_storage_volume.prowlarr_data.name
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
      hwaddr         = "10:66:6a:4f:fb:26"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.PROWLARR__AUTH__APIKEY" = sensitive(var.secrets.prowlarr_api_key)
    "environment.TZ"                     = var.timezone

    "user.access_interface" = "eth1"
  }
}
