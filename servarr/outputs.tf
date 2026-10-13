output "probes" {
  value = [
    "https://lidarr.${var.private_domain}/ping",
    "https://prowlarr.${var.private_domain}/ping",
    "https://radarr.${var.private_domain}/ping",
    "https://sonarr.${var.private_domain}/ping",
    "https://seerr.${var.private_domain}/api/v1/status",
  ]
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
