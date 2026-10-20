locals {
  sonarr_ports = {
    webui = 8989
  }

  sonarr_caddy = <<-EOT
  sonarr.${var.private_domain} {
  	reverse_proxy ${var.addresses.sonarr.ipv4}:${local.sonarr_ports.webui}
  }
  EOT
}

resource "incus_storage_volume" "sonarr_data" {
  name = "sonarr-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "sonarr" {
  name = "sonarr"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:hotio/sonarr:release-${var.versions.sonarr}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.sonarr_data.pool
      source = incus_storage_volume.sonarr_data.name
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
    properties = var.addresses.sonarr.nic
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.SONARR__AUTH__APIKEY"            = sensitive(var.secrets.sonarr_api_key)
    "environment.SONARR__SERVER__ALLOWEDHOSTS"    = "sonarr.${var.private_domain},${var.addresses.sonarr.ipv4}"
    "environment.SONARR__SERVER__TRUSTEDNETWORKS" = "${var.proxy_address}/32"
    "environment.TZ"                              = var.timezone
  }
}

resource "null_resource" "sonarr_restart" {
  triggers = {
    config = nonsensitive(sha1(jsonencode(incus_instance.sonarr.config)))
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.sonarr.name}"
  }
}
