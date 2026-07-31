variable "vaultwarden_version" {
  type    = string
  default = "1.37.1"
}

resource "incus_storage_volume" "vaultwarden_data" {
  name = "vaultwarden-data"
  pool = var.storage
}

resource "incus_instance" "vaultwarden" {
  name = "vaultwarden"
  type = "container"

  target   = var.target
  profiles = var.profiles
  image    = "ghcr:dani-garcia/vaultwarden:${var.vaultwarden_version}-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = var.storage
      source = incus_storage_volume.vaultwarden_data.name
    }
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
  }
}

