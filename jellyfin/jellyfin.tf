variable "jellyfin_version" {
  type    = string
  default = "10.11.11"
}

locals {
  jellyfin_ports = {
    webui = 8096
  }
}

resource "incus_storage_volume" "jellyfin_config" {
  name = "jellyfin-config"
  pool = "linstor"

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "jellyfin" {
  name = "jellyfin"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:hotio/jellyfin:release-${var.jellyfin_version}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.jellyfin_config.pool
      source = incus_storage_volume.jellyfin_config.name
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

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.TZ" = var.timezone

    "user.access_interface" = "eth1"
  }
}

output "ingress" {
  value = {
    name  = "jellyfin"
    caddy = <<-EOT
			jellyfin.${var.private_domain} {
				reverse_proxy ${incus_instance.jellyfin.ipv4_address}:${local.jellyfin_ports.webui}
			}
    EOT
  }
}
