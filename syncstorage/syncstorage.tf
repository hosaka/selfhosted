# todo: needs to actually wait for syncstorage_database to be healthy

locals {
  syncstorage_ports = {
    api = 8000
    db  = 5432
  }
}

resource "incus_instance" "syncstorage" {
  name = "syncstorage"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:mozilla-services/syncstorage-rs/syncserver-postgres:${var.versions.syncstorage}"

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.syncstorage.nic
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.RUST_LOG"                                  = "info"
    "environment.SYNC_HOST"                                 = "0.0.0.0"
    "environment.SYNC_PORT"                                 = "${local.syncstorage_ports.api}"
    "environment.SYNC_HUMAN_LOGS"                           = "false"
    "environment.SYNC_MASTER_SECRET"                        = sensitive(var.secrets.master_secret)
    "environment.SYNC_SYNCSTORAGE__DATABASE_URL"            = "postgres://${var.secrets.db_username}:${sensitive(var.secrets.db_password)}@${var.addresses.syncstorage_database.ipv4}:${local.syncstorage_ports.db}/${var.db_name}"
    "environment.SYNC_TOKENSERVER__DATABASE_URL"            = "postgres://${var.secrets.db_username}:${sensitive(var.secrets.db_password)}@${var.addresses.syncstorage_database.ipv4}:${local.syncstorage_ports.db}/${var.db_name}"
    "environment.SYNC_TOKENSERVER__ENABLED"                 = "true"
    "environment.SYNC_TOKENSERVER__RUN_MIGRATIONS"          = "true"
    "environment.SYNC_TOKENSERVER__NODE_TYPE"               = "postgres"
    "environment.SYNC_TOKENSERVER__FXA_EMAIL_DOMAIN"        = "api.accounts.firefox.com"
    "environment.SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL"    = "https://oauth.accounts.firefox.com"
    "environment.SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET" = sensitive(var.secrets.metrics_hash_secret)
    "environment.SYNC_TOKENSERVER__INIT_NODE_URL"           = "https://ffs.${var.public_domain}"
  }

  depends_on = [incus_instance.syncstorage_database]
}

resource "incus_storage_volume" "syncstorage_db" {
  name = "syncstorage-db"
  pool = "linstor"

  config = merge({
    # postgres user in alpine
    "initial.uid" = "70"
    "initial.gid" = "70"
  }, var.snapshots)
}

resource "incus_instance" "syncstorage_database" {
  name = "syncstorage-database"
  type = "container"

  target   = var.target
  profiles = ["default", "oci", "datastore"]
  image    = "docker:postgres:${var.versions.db}"

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
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.syncstorage_database.nic
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
    "https://ffs.${var.public_domain}/__heartbeat__",
  ]
}

output "backups" {
  value = {
    syncstorage = {
      volumes = {
        (incus_storage_volume.syncstorage_db.name) = {}
      }
      databases = [incus_instance.syncstorage_database.name]
    }
  }
}

output "ingress" {
  value = {
    name  = "ffs"
    caddy = <<-EOT
			ffs.${var.public_domain} {
				reverse_proxy ${var.addresses.syncstorage.ipv4}:${local.syncstorage_ports.api}
			}
    EOT
  }
}
