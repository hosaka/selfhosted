locals {
  voidrepo_ports = {
    http = 80
  }

  voidrepo_caddyfile = <<-EOT
		{
			auto_https off
		}

		:${local.voidrepo_ports.http} {
			handle_path /voidlinux* {
				root * /srv/voidrepo
				file_server browse {
					hide .partial
				}
			}
			respond 404
		}
  EOT
}

# Mirrors the x86_64 parts of the Void Linux repository on a schedule.
resource "incus_instance" "voidrepo_sync" {
  name = "voidrepo-sync"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "images:alpine/3.24/cloud"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data/voidrepo"
      pool   = var.storage_pool
      source = var.storage_source
    }
  }

  wait_for {
    type = "cloud-init"
  }

  config = {
    "cloud-init.user-data" = templatefile("${path.module}/user-data.yml.tpl", {
      sync_sh       = file("${path.module}/sync.sh")
      cron_schedule = var.cron_schedule
      rsync_args    = var.rsync_args
    })
  }
}

resource "incus_instance" "voidrepo" {
  name = "voidrepo"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:caddy:${var.versions.caddy}-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path     = "/srv/voidrepo"
      pool     = var.storage_pool
      source   = var.storage_source
      readonly = "true"
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = "10:66:6a:90:ac:b2"
    }
  }

  file {
    content     = local.voidrepo_caddyfile
    target_path = "/config/Caddyfile"
    mode        = "0644"
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /config/Caddyfile ]; do sleep 1; done; exec caddy run --config /config/Caddyfile --adapter caddyfile'"

    "user.access_interface" = "eth1"
  }
}

output "probes" {
  value = [
    "https://mirror.${var.public_domain}/voidlinux/",
    "https://mirror.${var.private_domain}/voidlinux/",
  ]
}

output "ingress" {
  value = {
    name  = "voidrepo"
    caddy = <<-EOT
			mirror.${var.private_domain}, mirror.${var.public_domain} {
				reverse_proxy ${incus_instance.voidrepo.ipv4_address}:${local.voidrepo_ports.http}
			}
    EOT
  }
}
