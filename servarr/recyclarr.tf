variable "recyclarr_version" {
  type    = string
  default = "8.7.0"
}

locals {
  recyclarr_config = templatefile("${path.module}/recyclarr.yml.tpl", {
    radarr_url     = "http://${incus_instance.radarr.ipv4_address}:${local.radarr_ports.webui}"
    radarr_api_key = sensitive(var.config.radarr_api_key)
    sonarr_url     = "http://${incus_instance.sonarr.ipv4_address}:${local.sonarr_ports.webui}"
    sonarr_api_key = sensitive(var.config.sonarr_api_key)
  })
}

resource "incus_instance" "recyclarr" {
  name = "recyclarr"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:recyclarr/recyclarr:${var.recyclarr_version}"

  file {
    content            = local.recyclarr_config
    target_path        = "/config/recyclarr.yml"
    mode               = "0644"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    # files are pushed after the instance starts, wait for the config before running the cron
    "oci.entrypoint" = "/sbin/tini -- /bin/sh -c 'while [ ! -f /config/recyclarr.yml ]; do sleep 1; done; exec /entrypoint.sh'"

    "user.access_interface" = "eth1"
  }
}
