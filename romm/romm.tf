locals {
  romm_ports = {
    webui = 8080
    db    = 5432
  }

  romm_url = "https://romm.${var.private_domain}"
}

resource "incus_storage_volume" "romm_assets" {
  name = "romm-assets"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_storage_volume" "romm_config" {
  name = "romm-config"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_storage_volume" "romm_resources" {
  name   = "romm-resources"
  pool   = var.cache_pool
  target = var.target

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_storage_volume" "romm_cache" {
  name   = "romm-cache"
  pool   = var.cache_pool
  target = var.target

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "romm" {
  name = "romm"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:rommapp/romm:${var.versions.romm}"

  device {
    name = "library"
    type = "disk"
    properties = {
      path   = "/romm/library"
      pool   = var.media_pool
      source = "${var.media_source}/collection/games"
    }
  }

  device {
    name = "assets"
    type = "disk"
    properties = {
      path   = "/romm/assets"
      pool   = incus_storage_volume.romm_assets.pool
      source = incus_storage_volume.romm_assets.name
    }
  }

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/romm/config"
      pool   = incus_storage_volume.romm_config.pool
      source = incus_storage_volume.romm_config.name
    }
  }

  device {
    name = "resources"
    type = "disk"
    properties = {
      path   = "/romm/resources"
      pool   = incus_storage_volume.romm_resources.pool
      source = incus_storage_volume.romm_resources.name
    }
  }

  device {
    name = "cache"
    type = "disk"
    properties = {
      path   = "/redis-data"
      pool   = incus_storage_volume.romm_cache.pool
      source = incus_storage_volume.romm_cache.name
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.romm.nic
  }

  file {
    content     = file("${path.module}/config.yml")
    target_path = "/romm/config/config.yml"
    mode        = "0644"
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.uid" = "1000"
    "oci.gid" = "1000"

    "environment.ROMM_BASE_URL"              = local.romm_url
    "environment.ROMM_AUTH_SECRET_KEY"       = sensitive(var.secrets.auth_secret_key)
    "environment.ROMM_SESSION_SECURE_COOKIE" = "true"
    "environment.FORWARDED_ALLOW_IPS"        = join(",", concat(["127.0.0.1", "::1"], var.trusted_proxies))

    "environment.ROMM_DB_DRIVER" = "postgresql"
    "environment.DB_HOST"        = var.addresses.romm_database.ipv4
    "environment.DB_PORT"        = local.romm_ports.db
    "environment.DB_NAME"        = var.db_name
    "environment.DB_USER"        = var.secrets.db_username
    "environment.DB_PASSWD"      = sensitive(var.secrets.db_password)

    "environment.OIDC_ENABLED"                = "true"
    "environment.OIDC_PROVIDER"               = "authelia"
    "environment.OIDC_CLIENT_ID"              = var.secrets.oidc_client_id
    "environment.OIDC_CLIENT_SECRET"          = sensitive(var.secrets.oidc_client_secret)
    "environment.OIDC_REDIRECT_URI"           = "${local.romm_url}/api/oauth/openid"
    "environment.OIDC_SERVER_APPLICATION_URL" = "https://auth.${var.public_domain}"
    "environment.OIDC_CLAIM_ROLES"            = "groups"
    "environment.OIDC_ROLE_ADMIN"             = "romm_admin"
    "environment.OIDC_ROLE_VIEWER"            = "romm_user"
    "environment.OIDC_AUTOLOGIN"              = "true"
    "environment.DISABLE_USERPASS_LOGIN"      = "true"
    "environment.DISABLE_SETUP_WIZARD"        = "true"

    "environment.IGDB_CLIENT_ID"                         = var.secrets.igdb_client_id
    "environment.IGDB_CLIENT_SECRET"                     = sensitive(var.secrets.igdb_client_secret)
    "environment.STEAMGRIDDB_API_KEY"                    = sensitive(var.secrets.steamgriddb_api_key)
    "environment.SCREENSCRAPER_USER"                     = var.secrets.screenscraper_user
    "environment.SCREENSCRAPER_PASSWORD"                 = sensitive(var.secrets.screenscraper_password)
    "environment.HASHEOUS_API_ENABLED"                   = "true"
    "environment.ENABLE_SCHEDULED_UPDATE_SWITCH_TITLEDB" = "true"
  }

  depends_on = [incus_instance.romm_database]
}

resource "null_resource" "romm_restart" {
  triggers = {
    config = nonsensitive(sha1(jsonencode(incus_instance.romm.config)))
    files  = sha1(jsonencode([for f in incus_instance.romm.file : [f.target_path, f.content]]))
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.romm.name}"
  }
}

resource "incus_storage_volume" "romm_db" {
  name = "romm-db"
  pool = "linstor"

  config = merge({
    # postgres user in alpine
    "initial.uid" = "70"
    "initial.gid" = "70"
  }, var.snapshots)
}

resource "incus_instance" "romm_database" {
  name = "romm-database"
  type = "container"

  target   = var.target
  profiles = ["default", "oci", "datastore"]
  image    = "docker:postgres:${var.versions.db}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/var/lib/postgresql"
      pool   = incus_storage_volume.romm_db.pool
      source = incus_storage_volume.romm_db.name
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.romm_database.nic
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

output "probes" {
  value = [
    "${local.romm_url}/api/heartbeat",
  ]
}

output "backups" {
  value = {
    romm = {
      volumes = {
        (incus_storage_volume.romm_assets.name) = {}
        (incus_storage_volume.romm_config.name) = {}
        (incus_storage_volume.romm_db.name)     = {}
      }
      databases = [incus_instance.romm_database.name]
    }
  }
}

output "ingress" {
  value = {
    name  = "romm"
    caddy = <<-EOT
			romm.${var.private_domain} {
				encode zstd gzip
				reverse_proxy ${var.addresses.romm.ipv4}:${local.romm_ports.webui}
			}
    EOT
  }
}
