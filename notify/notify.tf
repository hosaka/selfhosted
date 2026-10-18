locals {
  gotify_ports = {
    webui = 80
  }
}

resource "incus_storage_volume" "gotify_data" {
  name = "gotify-data"
  pool = "linstor"

  config = var.snapshots
}

# todo: fails to start if authelia is not reachable

resource "incus_instance" "gotify" {
  name = "gotify"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:gotify/server:${var.versions.gotify}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/app/data"
      pool   = incus_storage_volume.gotify_data.pool
      source = incus_storage_volume.gotify_data.name
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.gotify.nic
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.GOTIFY_OIDC_ENABLED"       = "true"
    "environment.GOTIFY_OIDC_ISSUER"        = "https://auth.${var.public_domain}"
    "environment.GOTIFY_OIDC_CLIENTID"      = "${var.secrets.oidc_client_id}"
    "environment.GOTIFY_OIDC_CLIENTSECRET"  = "${sensitive(var.secrets.oidc_client_secret)}"
    "environment.GOTIFY_OIDC_REDIRECTURL"   = "https://gotify.${var.public_domain}/auth/oidc/callback"
    "environment.GOTIFY_OIDC_AUTOREGISTER"  = "true"
    "environment.GOTIFY_OIDC_USERNAMECLAIM" = "preferred_username"
  }
}

resource "incus_storage_volume" "diun_data" {
  name = "diun-data"
  pool = "linstor"
}

resource "incus_instance" "diun" {
  name = "diun"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:crazy-max/diun:${var.versions.diun}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.diun_data.pool
      source = incus_storage_volume.diun_data.name
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.diun.nic
  }

  wait_for {
    type = "ipv4"
  }

  file {
    content     = file("${path.module}/diun.yml")
    target_path = "/config.yml"
    mode        = "0600"
  }

  # TODO: template this as a config file and pass it with --conifg, see https://crazymax.dev/diun/config/

  config = {
    "environment.DIUN_NOTIF_GOTIFY_ENDPOINT"   = "http://${var.addresses.gotify.ipv4}"
    "environment.DIUN_NOTIF_GOTIFY_TOKEN"      = "${sensitive(var.secrets.gotify_token)}"
    "environment.DIUN_WATCH_WORKERS"           = "10"
    "environment.DIUN_WATCH_SCHEDULE"          = "0 */6 * * *"
    "environment.DIUN_REGOPTS_0_NAME"          = "docker.io"
    "environment.DIUN_REGOPTS_0_SELECTOR"      = "image"
    "environment.DIUN_REGOPTS_0_USERNAME"      = "${var.secrets.dockerhub_username}"
    "environment.DIUN_REGOPTS_0_PASSWORD"      = "${sensitive(var.secrets.dockerhub_password)}"
    "environment.DIUN_REGOPTS_1_NAME"          = "ghcr.io"
    "environment.DIUN_REGOPTS_1_SELECTOR"      = "image"
    "environment.DIUN_REGOPTS_1_USERNAME"      = "${var.secrets.ghcr_username}"
    "environment.DIUN_REGOPTS_1_PASSWORD"      = "${sensitive(var.secrets.ghcr_password)}"
    "environment.DIUN_PROVIDERS_FILE_FILENAME" = "/config.yml"

    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /config.yml ]; do sleep 1; done; exec diun serve'"
  }
}

output "probes" {
  value = [
    "https://gotify.${var.public_domain}/health",
  ]
}

output "backups" {
  value = {
    gotify = {
      volumes = {
        (incus_storage_volume.gotify_data.name) = {}
      }
    }
  }
}

output "ingress" {
  value = {
    name  = "gotify"
    caddy = <<-EOT
			gotify.${var.public_domain} {
				reverse_proxy ${var.addresses.gotify.ipv4}:${local.gotify_ports.webui}
			}
    EOT
  }
}

output "gotify_address" {
  description = "Gotify's address, for services that send notifications"
  value       = "http://${var.addresses.gotify.ipv4}:${local.gotify_ports.webui}"
}
