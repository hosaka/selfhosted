variable "homeassistant_version" {
  type    = string
  default = "2026.7.4"
}

variable "mosquitto_version" {
  type    = string
  default = "2.0.22"
}

resource "incus_storage_volume" "homeassistant_data" {
  name = "homeassistant-data"
  pool = "remote"
}

resource "incus_instance" "homeassistant" {
  name = "homeassistant"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:home-assistant/home-assistant:${var.homeassistant_version}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.homeassistant_data.pool
      source = incus_storage_volume.homeassistant_data.name
    }
  }
}

resource "incus_storage_volume" "mosquitto_data" {
  name = "mosquitto-data"
  pool = "remote"
}

resource "incus_instance" "mosquitto" {
  name = "mosquitto"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:eclipse-mosquitto:${var.mosquitto_version}"

  file {
    content            = file("${path.module}/mosquitto.conf")
    target_path        = "/mosquitto/config/mosquitto.conf"
    mode               = "0600"
    create_directories = true
  }

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/mosquitto/data"
      pool   = incus_storage_volume.mosquitto_data.pool
      source = incus_storage_volume.mosquitto_data.name
    }
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /mosquitto/config/mosquitto.conf ]; do sleep 1; done; exec /docker-entrypoint.sh'"
  }
}
