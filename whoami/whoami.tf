variable "network" {
  type = object({
    ipv4 = string,
    mac  = string,
  })
}

variable "whoami_version" {
  type    = string
  default = "1.12.0"
}

resource "incus_instance" "whoami" {
  name = "whoami"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:traefik/whoami:v${var.whoami_version}"

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network        = "meshbr0"
      "ipv4.address" = var.network.ipv4
      hwaddr         = var.network.mac
    }
  }
}

output "ingress" {
  value = {
    name   = "whoami"
    public = true
    caddy  = <<-EOT
		whoami.${var.private_domain}, whoami.${var.public_domain} {
			reverse_proxy ${var.network.ipv4}:80
		}
    EOT
  }
}
