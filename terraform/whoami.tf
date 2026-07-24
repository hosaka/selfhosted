variable "whoami_version" {
  type = string
  default = "1.11.0"
}

resource "incus_image" "whoami" {
  alias {
    name = "whoami"
  }
  source_image = {
    remote = "ghcr"
    name   = "traefik/whoami:v${var.whoami_version}"
  }
}

resource "incus_instance" "whoami" {
  name     = "whoami"
  image    = incus_image.whoami.fingerprint
  profiles = ["default", incus_profile.base.name]

  config = {
    "environment.TZ" = "Asia/Tokyo"
  }
}

