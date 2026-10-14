locals {
  navidrome_ports = {
    webui = 4533
  }
}

resource "incus_storage_volume" "navidrome_data" {
  name = "navidrome-data"
  pool = "linstor"

  config = var.snapshots
}

resource "incus_instance" "navidrome" {
  name = "navidrome"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:navidrome/navidrome:${var.versions.navidrome}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.navidrome_data.pool
      source = incus_storage_volume.navidrome_data.name
    }
  }

  device {
    name = "music"
    type = "disk"
    properties = {
      path     = "/music"
      pool     = var.media_pool
      source   = "${var.media_source}/collection/music"
      readonly = "true"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.ND_SCANSCHEDULE"            = "@daily"
    "environment.ND_ENABLETRANSCODINGCONFIG" = "false"
    # data collection: https://www.navidrome.org/docs/getting-started/insights/
    "environment.ND_ENABLEINSIGHTSCOLLECTOR" = "true"

    # used to fetch artist images
    "environment.ND_LASTFM_ENABLED" = "true"
    "environment.ND_LASTFM_APIKEY"  = sensitive(var.secrets.lastfm_apikey)
    "environment.ND_LASTFM_SECRET"  = sensitive(var.secrets.lastfm_secret)
    # todo: enable external auth when it supports OIDC, ForwardAuth is a pain
    # see https://www.navidrome.org/docs/usage/integration/authentication/

    "user.access_interface" = "eth1"
  }
}

output "probes" {
  value = [
    "https://navidrome.${var.public_domain}/ping",
    "https://navidrome.${var.private_domain}/ping",
  ]
}

output "backups" {
  value = {
    navidrome = {
      volumes = {
        (incus_storage_volume.navidrome_data.name) = {}
      }
    }
  }
}

output "ingress" {
  value = {
    name  = "navidrome"
    caddy = <<-EOT
			navidrome.${var.private_domain}, navidrome.${var.public_domain} {
				reverse_proxy ${incus_instance.navidrome.ipv4_address}:${local.navidrome_ports.webui}
			}
    EOT
  }
}
