output "probes" {
  value = [
    "https://lidarr.${var.private_domain}/ping",
    "https://prowlarr.${var.private_domain}/ping",
    "https://radarr.${var.private_domain}/ping",
    "https://sonarr.${var.private_domain}/ping",
    "https://seerr.${var.private_domain}/api/v1/status",
  ]
}

output "backups" {
  value = {
    lidarr = {
      volumes = {
        (incus_storage_volume.lidarr_data.name) = {
          excludes = ["asp", "Backups", "MediaCover", "logs.*"]
        }
      }
    }

    prowlarr = {
      volumes = {
        (incus_storage_volume.prowlarr_data.name) = {
          excludes = ["asp", "Backups", "MediaCover", "logs.*", "Definitions"]
        }
      }
    }

    radarr = {
      volumes = {
        (incus_storage_volume.radarr_data.name) = {
          excludes = ["asp", "Backups", "MediaCover", "logs.*"]
        }
      }
    }

    recyclarr = {
      volumes = {
        (incus_storage_volume.recyclarr_data.name) = {
          excludes = ["repositories", "resources"]
        }
      }
    }

    seerr = {
      volumes = {
        (incus_storage_volume.seerr_data.name) = {
          excludes = [".local/share/pnpm"]
        }
      }
    }

    sonarr = {
      volumes = {
        (incus_storage_volume.sonarr_data.name) = {
          excludes = ["asp", "Backups", "MediaCover", "logs.*"]
        }
      }
    }
  }
}

output "ingress" {
  value = {
    name = "servarr"
    caddy = join("\n", [
      local.lidarr_caddy,
      local.prowlarr_caddy,
      local.radarr_caddy,
      local.seerr_caddy,
      local.sonarr_caddy,
    ])
  }
}

output "api_addresses" {
  description = "Web UI and API of each app, only reachable inside the cluster"
  value = {
    lidarr   = "${var.addresses.lidarr.ipv4}:${local.lidarr_ports.webui}"
    prowlarr = "${var.addresses.prowlarr.ipv4}:${local.prowlarr_ports.webui}"
    radarr   = "${var.addresses.radarr.ipv4}:${local.radarr_ports.webui}"
    sonarr   = "${var.addresses.sonarr.ipv4}:${local.sonarr_ports.webui}"
  }
}
