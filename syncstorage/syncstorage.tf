variable "syncstorage_version" {
  type    = string
  default = "0.23.3"
}

resource "incus_instance" "syncstorage" {
  name = "syncstorage"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:mozilla-services/syncstorage-rs/syncserver-postgres:${var.syncstorage_version}"

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "meshbr0"
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      network = "incusbr0"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.RUST_LOG"                                  = "info"
    "environment.SYNC_HOST"                                 = "0.0.0.0"
    "environment.SYNC_PORT"                                 = "8000"
    "environment.SYNC_HUMAN_LOGS"                           = "true"
    "environment.SYNC_MASTER_SECRET"                        = sensitive(var.config.master_secret)
    "environment.SYNC_SYNCSTORAGE__DATABASE_URL"            = "postgres://${var.config.db_username}:${sensitive(var.config.db_password)}@${incus_instance.syncstorage_database.ipv4_address}:5432/${var.config.db_name}"
    "environment.SYNC_TOKENSERVER__DATABASE_URL"            = "postgres://${var.config.db_username}:${sensitive(var.config.db_password)}@${incus_instance.syncstorage_database.ipv4_address}:5432/${var.config.db_name}"
    "environment.SYNC_TOKENSERVER__ENABLED"                 = "true"
    "environment.SYNC_TOKENSERVER__RUN_MIGRATIONS"          = "true"
    "environment.SYNC_TOKENSERVER__NODE_TYPE"               = "postgres"
    "environment.SYNC_TOKENSERVER__FXA_EMAIL_DOMAIN"        = "api.accounts.firefox.com"
    "environment.SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL"    = "https://oauth.accounts.firefox.com"
    "environment.SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET" = sensitive(var.config.metrics_hash_secret)
    "environment.SYNC_TOKENSERVER__INIT_NODE_URL"           = "https://ffs.${var.public_domain}"

    "user.access_interface" = "eth0"
  }
}

resource "incus_storage_volume" "syncstorage_db" {
  name = "syncstorage-db"
  pool = "linstor"
}

resource "incus_instance" "syncstorage_database" {
  name = "syncstorage-database"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:postgres:18-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/var/lib/postgresql"
      pool   = incus_storage_volume.syncstorage_db.pool
      source = incus_storage_volume.syncstorage_db.name
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "incusbr0"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.POSTGRES_DB"       = var.config.db_name
    "environment.POSTGRES_USER"     = var.config.db_username
    "environment.POSTGRES_PASSWORD" = sensitive(var.config.db_password)
    "environment.PGTZ"              = var.timezone

    "user.access_interface" = "eth0"
  }
}

output "ingress" {
  value = {
    name   = "ffs"
    public = true
    caddy  = <<-EOT
      ffs.${var.public_domain} {
        reverse_proxy ${incus_instance.syncstorage.ipv4_address}:8000
      }
    EOT
  }
}
