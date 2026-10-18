locals {
  recyclarr_config = templatefile("${path.module}/recyclarr.yml.tpl", {
    radarr_url     = "http://${var.addresses.radarr.ipv4}:${local.radarr_ports.webui}"
    radarr_api_key = sensitive(var.secrets.radarr_api_key)
    sonarr_url     = "http://${var.addresses.sonarr.ipv4}:${local.sonarr_ports.webui}"
    sonarr_api_key = sensitive(var.secrets.sonarr_api_key)
  })
}

resource "incus_storage_volume" "recyclarr_data" {
  name = "recyclarr-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "recyclarr" {
  name = "recyclarr"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:recyclarr/recyclarr:${var.versions.recyclarr}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.recyclarr_data.pool
      source = incus_storage_volume.recyclarr_data.name
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.recyclarr.nic
  }

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
  }

  depends_on = [incus_instance.radarr, incus_instance.sonarr]
}
