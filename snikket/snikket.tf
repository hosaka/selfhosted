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
  pool = "linstor"
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

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "meshbr0"
    }
  }

  wait_for {
    type = "ipv4"
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

    "user.access_interface" = "eth0"
  }
}

# resource "incus_instance" "snikket_certs" {
#   name = "snikket-certs"
#   type = "container"
#
#   target   = var.target
#   profiles = ["default"]
#   image    = "docker:snikket/snikket-cert-manager:${var.snikket_version}"
#
#   device {
#     name = "data"
#     type = "disk"
#     properties = {
#       path   = "/snikket"
#       pool   = incus_storage_volume.snikket_data.pool
#       source = incus_storage_volume.snikket_data.name
#     }
#   }
#
#   device {
#     name = "eth0"
#     type = "nic"
#     properties = {
#       network = "incusbr0"
#     }
#   }
#
#   wait_for {
#     type = "ipv4"
#   }
#
#   config = {
#     "environment.SNIKKET_DOMAIN"      = "chat.${var.public_domain}"
#     "environment.SNIKKET_ADMIN_EMAIL" = "admin@${var.public_domain}"
#   }
# }

resource "incus_instance" "snikket_web" {
  name = "snikket-web"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:snikket/snikket-web-portal:${var.snikket_version}"

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "meshbr0"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.SNIKKET_DOMAIN"                               = "chat.${var.public_domain}"
    "environment.SNIKKET_SITE_NAME"                            = "Sneaky Parakeet"
    "environment.SNIKKET_TWEAK_PORTAL_INTERNAL_HTTP_INTERFACE" = "0.0.0.0"
    "environment.SNIKKET_TWEAK_PORTAL_INTERNAL_HTTP_PORT"      = "${local.snikket_ports.webui}"
    # should point to the same port as SNIKKET_TWEAK_INTERNAL_HTTP_PORT
    "environment.SNIKKET_WEB_PROSODY_ENDPOINT" = "http://${incus_instance.snikket_server.ipv4_address}:${local.snikket_ports.api}"

    "user.access_interface" = "eth0"
  }
}

output "ingress" {
  value = {
    name   = "snikket"
    public = true
    caddy  = <<-EOT
			chat.${var.public_domain}, groups.chat.${var.public_domain}, share.chat.${var.public_domain} {
				# Prosody endpoints on the chat and share*/upload domain
				@prosody path /upload* /admin_api* /invites_api* /invites_bootstrap* /http-bind* /xmpp-websocket* /.well-known/host-meta /.well-known/host-meta.json
				handle @prosody {
					reverse_proxy ${incus_instance.snikket_server.ipv4_address}:5280
				}

				# everything else goes to web portal
				handle {
					reverse_proxy ${incus_instance.snikket_web.ipv4_address}:5765
				}
			}
    EOT
    frpc   = <<-EOT
		[[proxies]]
		name = "snikket-xmpp-c2s"
		type = "tcp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 5222
		remotePort = 5222

		[[proxies]]
		name = "snikket-xmpp-s2s"
		type = "tcp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 5269
		remotePort = 5269

		[[proxies]]
		name = "snikket-proxy65"
		type = "tcp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 5000
		remotePort = 5000

		[[proxies]]
		name = "snikket-stun-tcp"
		type = "tcp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 3478
		remotePort = 3478

		[[proxies]]
		name = "snikket-stun-udp"
		type = "udp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 3478
		remotePort = 3478

		[[proxies]]
		name = "snikket-turn-tcp"
		type = "tcp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 3479
		remotePort = 3479

		[[proxies]]
		name = "snikket-turn-udp"
		type = "udp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 3479
		remotePort = 3479

		[[proxies]]
		name = "snikket-stuns-tcp"
		type = "tcp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 5349
		remotePort = 5349

		[[proxies]]
		name = "snikket-stuns-udp"
		type = "udp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 5349
		remotePort = 5349

		[[proxies]]
		name = "snikket-turns-tcp"
		type = "tcp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 5350
		remotePort = 5350

		[[proxies]]
		name = "snikket-turns-udp"
		type = "udp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = 5350
		remotePort = 5350

		{{- range $_, $v := parseNumberRangePair "60000-60010" "60000-60010" }}
		[[proxies]]
		name = "snikket-data-{{ $v.First }}"
		type = "udp"
		localIP = "${incus_instance.snikket_server.ipv4_address}"
		localPort = {{ $v.First }}
		remotePort = {{ $v.Second }}
		{{- end }}
    EOT
  }
}
