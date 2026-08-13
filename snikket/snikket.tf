variable "snikket_version" {
  type    = string
  default = "stable.20260611"
}

locals {
  snikket_ports = {
    api     = 5280
    c2s     = 5222
    s2s     = 5269
    proxy65 = 5000
    webui   = 5765
    # AV negotiation and discovery proxy (STUN/TURN)
    # 3478-3479
    # AV negotiation and discovery proxy over TLS (STUNS/TURNS)
    # 5349-5350
    # AV data proxy (TURN data)
    turn_min = 60000
    turn_max = 60010
  }
}

# see: https://github.com/snikket-im/snikket-server
# see: https://snikket.org/service/help/advanced/firewall/
# see: https://snikket.org/service/help/advanced/reverse_proxy/

resource "incus_storage_volume" "snikket_data" {
  name = "snikket-data"
  pool = "remote"
}

resource "incus_instance" "snikket_server" {
  name = "snikket-server"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:snikket/snikket-server:${var.snikket_version}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/snikket"
      pool   = incus_storage_volume.snikket_data.pool
      source = incus_storage_volume.snikket_data.name
    }
  }

  config = {
    "environment.SNIKKET_DOMAIN"                        = "chat.${var.public_domain}"
    "environment.SNIKKET_ADMIN_EMAIL"                   = "admin@${var.public_domain}"
    "environment.SNIKKET_SITE_NAME"                     = "Sneaky Parakeet"
    "environment.SNIKKET_TWEAK_INTERNAL_HTTP_INTERFACE" = "0.0.0.0"
    "environment.SNIKKET_TWEAK_INTERNAL_HTTP_PORT"      = "${local.snikket_ports.api}"
    "environment.SNIKKET_TWEAK_STORAGE"                 = "sqlite"
    "environment.SNIKKET_TWEAK_TURNSERVER_MIN_PORT"     = "${local.snikket_ports.turn_min}"
    "environment.SNIKKET_TWEAK_TURNSERVER_MAX_PORT"     = "${local.snikket_ports.turn_max}"
    # currently defaults to `modern` which breaks iOS Snikket client login
    "environment.SNIKKET_TLS_PROFILE" = "intermediate"
    # disable support for legacy SASL, requiring all clients to support SASL2
    # increases security and speed, but a lot of clients do not have SASL2 support
    # "environment.SNIKKET_TWEAK_REQUIRE_SASL2" = "1"
    "environment.SNIKKET_UPDATE_CHECK" = "0"
  }
}

resource "incus_instance" "snikket_certs" {
  name = "snikket-certs"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:snikket/snikket-cert-manager:${var.snikket_version}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/snikket"
      pool   = incus_storage_volume.snikket_data.pool
      source = incus_storage_volume.snikket_data.name
    }
  }

  config = {
    "environment.SNIKKET_DOMAIN"      = "chat.${var.public_domain}"
    "environment.SNIKKET_ADMIN_EMAIL" = "admin@${var.public_domain}"
  }
}

resource "incus_instance" "snikket_web" {
  name = "snikket-web"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:snikket/snikket-web-portal:${var.snikket_version}"

  config = {
    "environment.SNIKKET_DOMAIN"                               = "chat.${var.public_domain}"
    "environment.SNIKKET_SITE_NAME"                            = "Sneaky Parakeet"
    "environment.SNIKKET_TWEAK_PORTAL_INTERNAL_HTTP_INTERFACE" = "0.0.0.0"
    "environment.SNIKKET_TWEAK_PORTAL_INTERNAL_HTTP_PORT"      = "${local.snikket_ports.webui}"
    # should point to the same port as SNIKKET_TWEAK_INTERNAL_HTTP_PORT
    "environment.SNIKKET_WEB_PROSODY_ENDPOINT" = "http://snikket:${local.snikket_ports.api}"
  }
}
