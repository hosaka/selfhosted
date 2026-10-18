locals {
  paperless_ports = {
    webui  = 8000
    db     = 5432
    valkey = 6379
  }
}

resource "incus_storage_volume" "paperless_data" {
  name = "paperless-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_storage_volume" "paperless_media" {
  name = "paperless-media"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "paperless" {
  name = "paperless"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:paperless-ngx/paperless-ngx:${var.versions.paperless}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/usr/src/paperless/data"
      pool   = incus_storage_volume.paperless_data.pool
      source = incus_storage_volume.paperless_data.name
    }
  }

  device {
    name = "media"
    type = "disk"
    properties = {
      path   = "/usr/src/paperless/media"
      pool   = incus_storage_volume.paperless_media.pool
      source = incus_storage_volume.paperless_media.name
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.paperless.nic
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.PAPERLESS_APPS" = "allauth.socialaccount.providers.openid_connect"
    # disable regular login form, leaving SSO as the only option
    "environment.PAPERLESS_DISABLE_REGULAR_LOGIN" = "True"
    # automatically redirect to the first configured SSO instead of the login form
    "environment.PAPERLESS_REDIRECT_LOGIN_TO_SSO" = "False"
    # automatically signup SSO users using retrieved email/username
    "environment.PAPERLESS_SOCIAL_AUTO_SIGNUP" = "False"
    # allow SSO users to signup for a new paperless account with a confirmation form
    "environment.PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS" = "True"
    "environment.PAPERLESS_SOCIALACCOUNT_PROVIDERS" = jsonencode({
      openid_connect = {
        SCOPE              = ["openid", "profile", "email"]
        OAUTH_PKCE_ENABLED = true
        APPS = [{
          provider_id = "authelia"
          name        = "Authelia"
          client_id   = var.secrets.oidc_client_id
          secret      = sensitive(var.secrets.oidc_client_secret)
          settings = {
            server_url        = "https://auth.${var.public_domain}"
            token_auth_method = "client_secret_basic"
          }
        }]
      }
    })
    "environment.PAPERLESS_URL"                  = "https://paperless.${var.public_domain}"
    "environment.PAPERLESS_ALLOWED_HOSTS"        = "localhost,paperless.${var.public_domain}"
    "environment.PAPERLESS_CSRF_TRUSTED_ORIGINS" = "https://paperless.${var.public_domain}"
    "environment.PAPERLESS_SECRET_KEY"           = sensitive(var.secrets.secret_key)
    "environment.PAPERLESS_ADMIN_USER"           = sensitive(var.secrets.admin_user)
    "environment.PAPERLESS_ADMIN_PASSWORD"       = sensitive(var.secrets.admin_password)

    "environment.PAPERLESS_REDIS"     = "redis://${var.addresses.paperless_valkey.ipv4}:${local.paperless_ports.valkey}"
    "environment.PAPERLESS_DBHOST"    = var.addresses.paperless_database.ipv4
    "environment.PAPERLESS_DBUSER"    = var.secrets.db_username
    "environment.PAPERLESS_DBPASS"    = sensitive(var.secrets.db_password)
    "environment.PAPERLESS_DBNAME"    = var.db_name
    "environment.PAPERLESS_TIME_ZONE" = var.timezone
  }

  depends_on = [incus_instance.paperless_database, incus_instance.paperless_valkey]
}

resource "incus_storage_volume" "paperless_db" {
  name = "paperless-db"
  pool = "linstor"

  config = merge({
    # postgres user in alpine
    "initial.uid" = "70"
    "initial.gid" = "70"
  }, var.snapshots)
}

resource "incus_instance" "paperless_database" {
  name = "paperless-database"
  type = "container"

  target   = var.target
  profiles = ["default", "oci", "datastore"]
  image    = "docker:postgres:${var.versions.db}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/var/lib/postgresql"
      pool   = incus_storage_volume.paperless_db.pool
      source = incus_storage_volume.paperless_db.name
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.paperless_database.nic
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.POSTGRES_DB"       = var.db_name
    "environment.POSTGRES_USER"     = var.secrets.db_username
    "environment.POSTGRES_PASSWORD" = sensitive(var.secrets.db_password)
    "environment.PGTZ"              = var.timezone
  }
}

resource "incus_storage_volume" "paperless_cache" {
  name = "paperless-cache"
  pool = "linstor"

  config = {
    # valkey user in alpine
    "initial.uid" = "999"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "paperless_valkey" {
  name = "paperless-valkey"
  type = "container"

  target   = var.target
  profiles = ["default", "oci", "datastore"]
  image    = "docker:valkey/valkey:${var.versions.cache}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.paperless_cache.pool
      source = incus_storage_volume.paperless_cache.name
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.paperless_valkey.nic
  }

  wait_for {
    type = "ipv4"
  }
}

output "probes" {
  value = [
    "https://paperless.${var.public_domain}/",
  ]
}

output "backups" {
  value = {
    paperless = {
      volumes = {
        (incus_storage_volume.paperless_data.name) = {
          excludes = [".index_version", "index/.tantivy-*.lock", "migration_lock"]
        }
        (incus_storage_volume.paperless_media.name) = {}
        (incus_storage_volume.paperless_db.name)    = {}
      }
      databases = [incus_instance.paperless_database.name]
    }
  }
}

output "ingress" {
  value = {
    name  = "paperless"
    caddy = <<-EOT
			paperless.${var.public_domain} {
				reverse_proxy ${var.addresses.paperless.ipv4}:${local.paperless_ports.webui}
				@admin {
					path /admin*
					not remote_ip private_ranges
				}
				respond @admin "401 - {remote_host} is not an allowed IP" 401
			}
    EOT
  }
}
