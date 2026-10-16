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
      hwaddr  = "10:66:6a:db:01:fb"
    }
  }

  wait_for {
    type = "ipv4"
  }
}

output "probes" {
  value = [
    "https://whoami.${var.public_domain}/",
    "https://whoami.${var.private_domain}/",
  ]
}

output "ingress" {
  value = {
    name  = "whoami"
    caddy = <<-EOT
		whoami.${var.private_domain}, whoami.${var.public_domain} {
			reverse_proxy ${incus_instance.whoami.ipv4_address}:${local.whoami_ports.http}
		}
    EOT
  }
}
