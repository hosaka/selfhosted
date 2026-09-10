variable "vaultwarden_version" {
  type    = string
  default = "1.37.2"
}

resource "incus_storage_volume" "vaultwarden_data" {
  name = "vaultwarden-data"
  pool = "linstor"
}

resource "incus_instance" "vaultwarden" {
  name = "vaultwarden"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:dani-garcia/vaultwarden:${var.vaultwarden_version}-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.vaultwarden_data.pool
      source = incus_storage_volume.vaultwarden_data.name
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
    "environment.ADMIN_TOKEN"            = sensitive(var.config.admin_token)
    "environment.DOMAIN"                 = "https://vaultwarden.${var.public_domain}"
    "environment.INVITATIONS_ALLOWED"    = "false"
    "environment.ORG_CREATION_USERS"     = "none"
    "environment.PASSWORD_HINTS_ALLOWED" = "false"
    "environment.SHOW_PASSWORD_HINT"     = "false"
    "environment.SIGNUPS_ALLOWED"        = "false"
    "environment.SMTP_FROM"              = var.config.smtp_from
    "environment.SMTP_HOST"              = var.config.smtp_host
    "environment.SMTP_PASSWORD"          = sensitive(var.config.smtp_password)
    "environment.SMTP_PORT"              = var.config.smtp_port
    "environment.SMTP_SECURITY"          = var.config.smtp_security
    "environment.SMTP_USERNAME"          = sensitive(var.config.smtp_username)
    "environment.SSO_ENABLED"            = "true"
    "environment.SSO_ONLY"               = "false"
    # on SSO signup associate a user with a matching email that already exists
    "environment.SSO_SIGNUPS_MATCH_EMAIL" = "true"
    "environment.SSO_AUTHORITY"           = "https://auth.${var.public_domain}"
    # openid scope is implicit and does not need to be included here
    "environment.SSO_SCOPES"        = "email profile offline_access vaultwarden"
    "environment.SSO_PKCE"          = "true"
    "environment.SSO_CLIENT_ID"     = var.config.oidc_client_id
    "environment.SSO_CLIENT_SECRET" = sensitive(var.config.oidc_client_secret)
    "environment.YUBICO_CLIENT_ID"  = var.config.yubico_client_id
    "environment.YUBICO_SECRET_KEY" = sensitive(var.config.yubico_secret_key)
    "environment.TZ"                = var.timezone

    "user.access_interface" = "eth0"
  }
}

output "ingress" {
  value = {
    name   = "vaultwarden"
    public = true
    caddy  = <<-EOT
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
        reverse_proxy ${incus_instance.vaultwarden.ipv4_address}:80 {
          # send the true remote IP to Rocket, so fail2ban can ban collect IPs from the log
          header_up X-Real-IP {remote_host}
        }
      }
    EOT
  }
}
