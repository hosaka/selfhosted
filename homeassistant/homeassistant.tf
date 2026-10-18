locals {
  homeassistant_ports = {
    webui = 8123
    mqtt  = 1883
  }
}

resource "incus_storage_volume" "homeassistant_data" {
  name = "homeassistant-data"
  pool = "linstor"

  config = var.snapshots
}

resource "incus_instance" "homeassistant" {
  name = "homeassistant"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:home-assistant/home-assistant:${var.versions.homeassistant}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.homeassistant_data.pool
      source = incus_storage_volume.homeassistant_data.name
    }
  }

  # todo: if the service relies on mDNS or device discovery, it probably needs a NIC on lan

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.homeassistant.nic
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.TZ" = var.timezone
  }
}

# resource "incus_storage_volume" "mosquitto_data" {
#   name = "mosquitto-data"
#   pool = "linstor"
# }
#
# resource "incus_instance" "mosquitto" {
#   name = "mosquitto"
#   type = "container"
#
#   target   = var.target
#   profiles = ["default"]
#   image    = "docker:eclipse-mosquitto:${var.versions.mosquitto}"
#
#   file {
#     content            = file("${path.module}/mosquitto.conf")
#     target_path        = "/mosquitto/config/mosquitto.conf"
#     mode               = "0600"
#     create_directories = true
#   }
#
#   device {
#     name = "data"
#     type = "disk"
#     properties = {
#       path   = "/mosquitto/data"
#       pool   = incus_storage_volume.mosquitto_data.pool
#       source = incus_storage_volume.mosquitto_data.name
#     }
#   }
#
#   device {
#     name       = "eth0"
#     type       = "nic"
#     properties = var.addresses.mosquitto.nic
#   }
#
#   wait_for {
#     type = "ipv4"
#   }
#
#   config = {
#     # overriding the entrypoint drops the image's CMD, so pass the mosquitto command to the original entrypoint explicitly
#     # mosquitto.conf points at a password file and refuses to start without one, create an empty one on a fresh volume
#     "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /mosquitto/config/mosquitto.conf ]; do sleep 1; done; [ -f /mosquitto/data/pwfile ] || install -m 0700 /dev/null /mosquitto/data/pwfile; exec /docker-entrypoint.sh /usr/sbin/mosquitto -c /mosquitto/config/mosquitto.conf'"
#   }
# }

output "backups" {
  value = {
    homeassistant = {
      volumes = {
        (incus_storage_volume.homeassistant_data.name) = {
          excludes = ["backups", "home-assistant.log.*"]
        }
      }
    }
  }
}

output "ingress" {
  value = {
    name  = "homeassistant"
    caddy = <<-EOT
			hass.${var.private_domain} {
				reverse_proxy ${var.addresses.homeassistant.ipv4}:${local.homeassistant_ports.webui}
			}
    EOT
  }
}
