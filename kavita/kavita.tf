locals {
  kavita_ports = {
    webui = 5000
  }
}

resource "incus_storage_volume" "kavita_data" {
  name = "kavita-data"
  pool = "linstor"

  config = var.snapshots
}

resource "incus_instance" "kavita" {
  name = "kavita"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:kareadita/kavita:${var.versions.kavita}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/kavita/config"
      pool   = incus_storage_volume.kavita_data.pool
      source = incus_storage_volume.kavita_data.name
    }
  }

  device {
    name = "books"
    type = "disk"
    properties = {
      path     = "/data/media"
      pool     = var.media_pool
      source   = "${var.media_source}/collection/books"
      readonly = "true"
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

output "probes" {
  value = [
    "https://kavita.${var.private_domain}/api/health",
  ]
}

output "backups" {
  value = {
    kavita = {
      volumes = {
        (incus_storage_volume.kavita_data.name) = {
          excludes = ["backups"]
        }
      }
    }
  }
}

output "ingress" {
  value = {
    name  = "kavita"
    caddy = <<-EOT
			kavita.${var.private_domain} {
				encode gzip
				reverse_proxy ${incus_instance.kavita.ipv4_address}:${local.kavita_ports.webui}
			}
    EOT
  }
}
