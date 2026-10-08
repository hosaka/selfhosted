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
