variable "wakapi_version" {
  type    = string
  default = "2.17.5"
}

resource "incus_storage_volume" "wakapi_data" {
  name = "wakapi-data"
  pool = "linstor"

  config = {
    "initial.uid" = "65532"
    "initial.gid" = "65532"
  }
}

# todo: fails to start if authelia is not reachable

resource "incus_instance" "wakapi" {
  name = "wakapi"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:muety/wakapi:${var.wakapi_version}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/app/data"
      pool   = incus_storage_volume.wakapi_data.pool
      source = incus_storage_volume.wakapi_data.name
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "incusbr0"
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      network = "meshbr0"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.WAKAPI_PUBLIC_URL"                     = "https://waka.${var.public_domain}"
    "environment.WAKAPI_DB_NAME"                        = "/app/data/wakapi.db"
    "environment.WAKAPI_PASSWORD_SALT"                  = "${sensitive(var.config.password_salt)}"
    "environment.WAKAPI_INSECURE_COOKIES"               = "false"
    "environment.WAKAPI_ALLOW_SIGNUP"                   = "false"
    "environment.WAKAPI_DISABLE_FRONTPAGE"              = "true"
    "environment.WAKAPI_OIDC_ALLOW_SIGNUP"              = "false"
    "environment.WAKAPI_OIDC_PROVIDERS_0_NAME"          = "authelia"
    "environment.WAKAPI_OIDC_PROVIDERS_0_DISPLAY_NAME"  = "Authelia"
    "environment.WAKAPI_OIDC_PROVIDERS_0_CLIENT_ID"     = "${var.config.oidc_client_id}"
    "environment.WAKAPI_OIDC_PROVIDERS_0_CLIENT_SECRET" = "${sensitive(var.config.oidc_client_secret)}"
    "environment.WAKAPI_OIDC_PROVIDERS_0_ENDPOINT"      = "https://auth.${var.public_domain}"
    "environment.TZ"                                    = var.timezone

    "user.access_interface" = "eth1"
  }
}

output "ingress" {
  value = {
    name = "waka"
    domains = [
      "waka.${var.public_domain}"
    ]
    caddy = <<-EOT
			waka.${var.public_domain} {
				reverse_proxy ${incus_instance.wakapi.ipv4_address}:3000
			}
    EOT
  }
}
