locals {
  kavita_ports = {
    webui = 5000
  }
}

resource "incus_storage_volume" "kavita_config" {
  name = "kavita-config"
  pool = "linstor"
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
      pool   = incus_storage_volume.kavita_config.pool
      source = incus_storage_volume.kavita_config.name
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
