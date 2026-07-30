variable "atuin_version" {
  type    = string
  default = "18.16.1"
}

resource "incus_instance" "atuin" {
  name = "atuin"
  type = "container"

  target   = var.target
  profiles = var.profiles
  image    = "ghcr:atuinsh/atuin:${var.atuin_version}"

  config = {
    "environment.ATUIN_HOST"              = "0.0.0.0"
    "environment.ATUIN_OPEN_REGISTRATION" = "false"
    "environment.ATUIN_DB_URI"            = "postgres://${var.config.db_username}:${sensitive(var.config.db_password)}@${incus_instance.atuin_database.name}/${var.config.db_name}"

    "oci.entrypoint" = "/usr/local/bin/atuin-server start"
  }
}

resource "incus_storage_volume" "atuin_database" {
  name = "atuin-database"
  pool = var.storage
}

resource "incus_instance" "atuin_database" {
  name = "atuin-database"
  type = "container"

  target   = var.target
  profiles = var.profiles
  image    = "docker:postgres:18-alpine"

  device {
    name = "database"
    type = "disk"
    properties = {
      path   = "/var/lib/postgresql"
      pool   = var.storage
      source = incus_storage_volume.atuin_database.name
    }
  }

  config = {
    "environment.POSTGRES_DB"       = var.config.db_name
    "environment.POSTGRES_USER"     = var.config.db_username
    "environment.POSTGRES_PASSWORD" = sensitive(var.config.db_password)
    "environment.PGTZ"              = var.timezone
  }
}

