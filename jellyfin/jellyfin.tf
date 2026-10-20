locals {
  jellyfin_ports = {
    webui = 8096
  }
}

resource "incus_storage_volume" "jellyfin_data" {
  name = "jellyfin-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_storage_volume" "jellyfin_transcodes" {
  name   = "jellyfin-transcodes"
  pool   = "local"
  target = var.target

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
    "size"        = "20GiB"
  }
}

resource "incus_instance" "jellyfin" {
  name = "jellyfin"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:hotio/jellyfin:release-${var.versions.jellyfin}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.jellyfin_data.pool
      source = incus_storage_volume.jellyfin_data.name
    }
  }

  device {
    name = "transcodes"
    type = "disk"
    properties = {
      path   = "/config/cache/transcodes"
      pool   = incus_storage_volume.jellyfin_transcodes.pool
      source = incus_storage_volume.jellyfin_transcodes.name
    }
  }

  device {
    name = "collection"
    type = "disk"
    properties = {
      path   = "/data/media/collection"
      pool   = var.media_pool
      source = "${var.media_source}/collection"
    }
  }

  # owned by the hotio user's group so no extra group membership is needed inside the container
  device {
    name = "gpu"
    type = "gpu"
    properties = {
      gputype = "physical"
      gid     = "1000"
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.jellyfin.nic
  }

  file {
    content     = file("${path.module}/logging.default.json")
    target_path = "/config/logging.default.json"
    mode        = "0644"
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.TZ" = var.timezone
  }
}

resource "null_resource" "jellyfin_restart" {
  triggers = {
    logging = sha1(file("${path.module}/logging.default.json"))
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.jellyfin.name}"
  }
}

output "probes" {
  value = [
    "https://jellyfin.${var.private_domain}/health",
  ]
}

output "backups" {
  value = {
    jellyfin = {
      volumes = {
        (incus_storage_volume.jellyfin_data.name) = {
          excludes = ["dlna"]
        }
      }
    }
  }
}

output "ingress" {
  value = {
    name  = "jellyfin"
    caddy = <<-EOT
			jellyfin.${var.private_domain} {
				reverse_proxy ${var.addresses.jellyfin.ipv4}:${local.jellyfin_ports.webui}
			}
    EOT
  }
}
