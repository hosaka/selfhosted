variable "atuin_version" {
  type    = string
  default = "18.16.1"
}

resource "incus_storage_volume" "atuin_database" {
  name = "atuin-database"
  pool = "local"
}

resource "incus_instance" "atuin_database" {
  name     = "atuin-database"
  type     = "container"
  target   = var.cluster.node-1.target
  profiles = [incus_profile.default.name]
  image    = "docker:postgres:18-alpine"

  device {
    name = "database"
    type = "disk"
    properties = {
      path   = "/var/lib/postgresql"
      pool   = "local"
      source = incus_storage_volume.atuin_database.name
    }
  }

  config = {
    "environment.POSTGRES_DB"       = var.atuin_db_name
    "environment.POSTGRES_USER"     = var.atuin_db_username
    "environment.POSTGRES_PASSWORD" = var.atuin_db_password
    "environment.PGTZ"              = var.timezone
  }
}

resource "incus_instance" "atuin" {
  depends_on = [incus_instance.atuin_database]

  name     = "atuin"
  type     = "container"
  target   = var.cluster.node-1.target
  profiles = [incus_profile.default.name]
  image    = "ghcr:atuinsh/atuin:${var.atuin_version}"

  config = {
    "environment.ATUIN_HOST"              = "0.0.0.0"
    "environment.ATUIN_OPEN_REGISTRATION" = "false"
    "environment.ATUIN_DB_URI"            = "postgres://${var.atuin_db_username}:${var.atuin_db_password}@atuin-database/${var.atuin_db_name}"

    "oci.entrypoint" = "/usr/local/bin/atuin-server start"
  }
}

