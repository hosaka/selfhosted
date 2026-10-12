locals {
  vaultwarden_ports = {
    webui = 80
  }
}

resource "incus_storage_volume" "vaultwarden_data" {
  name = "vaultwarden-data"
  pool = "linstor"
}

resource "incus_instance" "vaultwarden" {
  name = "vaultwarden"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:dani-garcia/vaultwarden:${var.versions.vaultwarden}-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.vaultwarden_data.pool
      source = incus_storage_volume.vaultwarden_data.name
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.ADMIN_TOKEN"            = sensitive(var.secrets.admin_token)
    "environment.DOMAIN"                 = "https://vaultwarden.${var.public_domain}"
    "environment.INVITATIONS_ALLOWED"    = "false"
    "environment.ORG_CREATION_USERS"     = "none"
    "environment.PASSWORD_HINTS_ALLOWED" = "false"
    "environment.SHOW_PASSWORD_HINT"     = "false"
    "environment.SIGNUPS_ALLOWED"        = "false"
    "environment.SMTP_FROM"              = coalesce(var.smtp_from, "admin@${var.public_domain}")
    "environment.SMTP_HOST"              = var.secrets.smtp_host
    "environment.SMTP_PASSWORD"          = sensitive(var.secrets.smtp_password)
    "environment.SMTP_PORT"              = var.smtp_port
    "environment.SMTP_SECURITY"          = var.smtp_security
    "environment.SMTP_USERNAME"          = sensitive(var.secrets.smtp_username)
    "environment.SSO_ENABLED"            = "true"
    "environment.SSO_ONLY"               = "false"
    # on SSO signup associate a user with a matching email that already exists
    "environment.SSO_SIGNUPS_MATCH_EMAIL" = "true"
    "environment.SSO_AUTHORITY"           = "https://auth.${var.public_domain}"
    # openid scope is implicit and does not need to be included here
    "environment.SSO_SCOPES"        = "email profile offline_access vaultwarden"
    "environment.SSO_PKCE"          = "true"
    "environment.SSO_CLIENT_ID"     = var.secrets.oidc_client_id
    "environment.SSO_CLIENT_SECRET" = sensitive(var.secrets.oidc_client_secret)
    "environment.YUBICO_CLIENT_ID"  = var.secrets.yubico_client_id
    "environment.YUBICO_SECRET_KEY" = sensitive(var.secrets.yubico_secret_key)
    "environment.TZ"                = var.timezone

    "user.access_interface" = "eth1"
  }
}

output "ingress" {
  value = {
    name  = "vaultwarden"
    caddy = <<-EOT
			vaultwarden.${var.private_domain}, vaultwarden.${var.public_domain} {
				encode zstd gzip

				header {
					# enable HTTP Strict Transport Security (HSTS)
					Strict-Transport-Security "max-age=31536000; preload"
					# disable enable cross-site filter (XSS)
					X-XSS-Protection "0"
					# disallow sniffing of X-Content-Type-Options
					X-Content-Type-Options "nosniff"
					# disallow the site to be rendered within a frame (clickjacking protection)
					X-Frame-Options "SAMEORIGIN"
					# prevent search engines from indexing
					X-Robots-Tag "none"
					# remove server name
					-Server
				}

				# allow access to the admin interface only from local networks
				@admin {
					path /admin*
					not remote_ip private_ranges
				}
				respond @admin "401 - {remote_host} is not an allowed IP" 401

				# proxy everything to Rocket
				reverse_proxy ${incus_instance.vaultwarden.ipv4_address}:${local.vaultwarden_ports.webui} {
					# send the true remote IP to Rocket, so fail2ban can ban collect IPs from the log
					header_up X-Real-IP {remote_host}
				}
			}
    EOT
  }
}
