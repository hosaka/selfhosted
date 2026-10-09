locals {
  atuin_ports = {
    api = 8888
    db  = 5432
  }
}

resource "incus_instance" "atuin" {
  name = "atuin"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:atuinsh/atuin:${var.versions.atuin}"

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.ATUIN_HOST"              = "0.0.0.0"
    "environment.ATUIN_OPEN_REGISTRATION" = "false"
    "environment.ATUIN_DB_URI"            = "postgres://${var.secrets.db_username}:${sensitive(var.secrets.db_password)}@${incus_instance.atuin_database.ipv4_address}/${var.db_name}"

    "oci.entrypoint" = "/usr/local/bin/atuin-server start"

    "user.access_interface" = "eth1"
  }
}

resource "incus_storage_volume" "atuin_db" {
  name = "atuin-db"
  pool = "linstor"

  config = {
    # postgres user in alpine
    "initial.uid" = "70"
    "initial.gid" = "70"
  }
}

resource "incus_instance" "atuin_database" {
  name = "atuin-database"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:postgres:18-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/var/lib/postgresql"
      pool   = incus_storage_volume.atuin_db.pool
      source = incus_storage_volume.atuin_db.name
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
    "environment.POSTGRES_DB"       = var.db_name
    "environment.POSTGRES_USER"     = var.secrets.db_username
    "environment.POSTGRES_PASSWORD" = sensitive(var.secrets.db_password)
    "environment.PGTZ"              = var.timezone

    "user.access_interface" = "eth0"
  }
}

output "ingress" {
  value = {
    name = "atuin"
    domains = [
      "atuin.${var.public_domain}"
    ]
    caddy = <<-EOT
			atuin.${var.public_domain} {
				reverse_proxy ${incus_instance.atuin.ipv4_address}:${local.atuin_ports.api}
			}
    EOT
  }
}
