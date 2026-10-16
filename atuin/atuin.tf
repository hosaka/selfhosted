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
  profiles = ["default"]
  image    = "ghcr:atuinsh/atuin:${var.versions.atuin}"

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = "10:66:6a:fe:55:8a"
    }
  }

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

  config = merge({
    # postgres user in alpine
    "initial.uid" = "70"
    "initial.gid" = "70"
  }, var.snapshots)
}

resource "incus_instance" "atuin_database" {
  name = "atuin-database"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:postgres:${var.versions.db}"

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
      hwaddr  = "10:66:6a:5c:3d:15"
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

output "probes" {
  value = [
    "https://atuin.${var.public_domain}/healthz",
  ]
}

output "backups" {
  value = {
    atuin = {
      volumes = {
        (incus_storage_volume.atuin_db.name) = {}
      }
      databases = [incus_instance.atuin_database.name]
    }
  }
}

output "ingress" {
  value = {
    name  = "atuin"
    caddy = <<-EOT
			atuin.${var.public_domain} {
				reverse_proxy ${incus_instance.atuin.ipv4_address}:${local.atuin_ports.api}
			}
    EOT
  }
}
