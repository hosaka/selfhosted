locals {
  whoami_ports = {
    http = 80
  }
}

resource "incus_instance" "whoami" {
  name = "whoami"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:traefik/whoami:v${var.versions.whoami}"

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
}

output "ingress" {
  value = {
    name = "whoami"
    domains = [
      "whoami.${var.public_domain}"
    ]
    caddy = <<-EOT
		whoami.${var.private_domain}, whoami.${var.public_domain} {
			reverse_proxy ${incus_instance.whoami.ipv4_address}:${local.whoami_ports.http}
		}
    EOT
  }
}
