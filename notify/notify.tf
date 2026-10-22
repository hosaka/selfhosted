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
    "environment.GOTIFY_OIDC_ENABLED"          = "true"
    "environment.GOTIFY_OIDC_ISSUER"           = "https://auth.${var.public_domain}"
    "environment.GOTIFY_OIDC_CLIENTID"         = "${var.secrets.oidc_client_id}"
    "environment.GOTIFY_OIDC_CLIENTSECRET"     = "${sensitive(var.secrets.oidc_client_secret)}"
    "environment.GOTIFY_OIDC_REDIRECTURL"      = "https://gotify.${var.public_domain}/auth/oidc/callback"
    "environment.GOTIFY_OIDC_AUTOREGISTER"     = "true"
    "environment.GOTIFY_OIDC_USERNAMECLAIM"    = "preferred_username"
    "environment.GOTIFY_OIDC_SCOPES"           = "openid,profile,email,groups"
    "environment.GOTIFY_OIDC_GROUPS_CLAIM"     = "groups"
    "environment.GOTIFY_OIDC_GROUPS_USER"      = "gotify_user"
    "environment.GOTIFY_OIDC_GROUPS_ADMIN"     = "gotify_admin"
    "environment.GOTIFY_OIDC_LINK_BY_USERNAME" = "true"
    "environment.GOTIFY_LOCALAUTH_ENABLED"     = "false"

    # gotify exits when it can't fetch the OIDC discovery document at startup
    "oci.entrypoint" = "/bin/sh -c 'until curl -fsS https://auth.${var.public_domain}/.well-known/openid-configuration >/dev/null; do sleep 2; done; exec /app/gotify-app serve'"
  }
}

resource "null_resource" "gotify_restart" {
  triggers = {
    config = nonsensitive(sha1(jsonencode(incus_instance.gotify.config)))
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.gotify.name}"
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
