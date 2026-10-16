locals {
  immich_ports = {
    webui            = 2283
    api_metrics      = 8081
    jobs_metrics     = 8082
    machine_learning = 3003
    db               = 5432
    valkey           = 6379
  }
}

resource "incus_instance" "immich" {
  name = "immich"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:immich-app/immich-server:v${var.versions.immich}"

  device {
    name = "storage"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = var.storage_pool
      source = var.storage_source
    }
  }

  #  hardware transcoding
  device {
    name = "gpu"
    type = "gpu"
    properties = {
      gputype = "physical"
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = "10:66:6a:c5:be:fa"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.IMMICH_ENV"                        = "production"
    "environment.IMMICH_LOG_LEVEL"                  = var.log_level
    "environment.IMMICH_TELEMETRY_INCLUDE"          = "all"
    "environment.IMMICH_API_METRICS_PORT"           = local.immich_ports.api_metrics
    "environment.IMMICH_MICROSERVICES_METRICS_PORT" = local.immich_ports.jobs_metrics
    "environment.DB_HOSTNAME"                       = incus_instance.immich_database.ipv4_address
    "environment.DB_USERNAME"                       = var.secrets.db_username
    "environment.DB_PASSWORD"                       = sensitive(var.secrets.db_password)
    "environment.DB_DATABASE_NAME"                  = var.db_name
    "environment.REDIS_HOSTNAME"                    = incus_instance.immich_valkey.ipv4_address
    "environment.IMMICH_MACHINE_LEARNING_URL"       = "http://${incus_instance.immich_machine_learning.ipv4_address}:${local.immich_ports.machine_learning}"
    "environment.TZ"                                = var.timezone

    "user.access_interface" = "eth1"
  }
}

resource "incus_storage_volume" "immich_model_cache" {
  name = "immich-model-cache"
  pool = "linstor"
}

resource "incus_instance" "immich_machine_learning" {
  name = "immich-machine-learning"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:immich-app/immich-machine-learning:v${var.versions.immich}"

  device {
    name = "cache"
    type = "disk"
    properties = {
      path   = "/cache"
      pool   = incus_storage_volume.immich_model_cache.pool
      source = incus_storage_volume.immich_model_cache.name
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "incusbr0"
      hwaddr  = "10:66:6a:fb:94:c6"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "user.access_interface" = "eth0"
  }
}

resource "incus_storage_volume" "immich_db" {
  name = "immich-db"
  pool = "linstor"

  config = merge({
    # postgres user in debian
    "initial.uid" = "999"
    "initial.gid" = "999"
  }, var.snapshots)
}

resource "incus_instance" "immich_database" {
  name = "immich-database"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:immich-app/postgres:${var.versions.db}"

  # mounted one level above PGDATA so initdb gets an empty directory
  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/var/lib/postgresql"
      pool   = incus_storage_volume.immich_db.pool
      source = incus_storage_volume.immich_db.name
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "incusbr0"
      hwaddr  = "10:66:6a:2a:a0:b4"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.POSTGRES_DB"          = var.db_name
    "environment.POSTGRES_USER"        = var.secrets.db_username
    "environment.POSTGRES_PASSWORD"    = sensitive(var.secrets.db_password)
    "environment.POSTGRES_INITDB_ARGS" = "--data-checksums"
    "environment.PGTZ"                 = var.timezone

    "user.access_interface" = "eth0"
  }
}

resource "incus_storage_volume" "immich_cache" {
  name = "immich-cache"
  pool = "linstor"

  config = {
    # valkey user in alpine
    "initial.uid" = "999"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "immich_valkey" {
  name = "immich-valkey"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:valkey/valkey:${var.versions.cache}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.immich_cache.pool
      source = incus_storage_volume.immich_cache.name
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "incusbr0"
      hwaddr  = "10:66:6a:3d:49:83"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "user.access_interface" = "eth0"
  }
}

resource "null_resource" "immich_restart" {
  triggers = {
    config = nonsensitive(sha1(jsonencode(incus_instance.immich.config)))
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.immich.name}"
  }
}

output "probes" {
  value = [
    "https://immich.${var.public_domain}/api/server/ping",
    "https://immich.${var.private_domain}/api/server/ping",
  ]
}

output "backups" {
  value = {
    immich = {
      volumes = {
        (incus_storage_volume.immich_db.name) = {}
      }
      databases = [incus_instance.immich_database.name]
    }
  }
}

output "ingress" {
  value = {
    name  = "immich"
    caddy = <<-EOT
			immich.${var.private_domain}, immich.${var.public_domain} {
				reverse_proxy ${incus_instance.immich.ipv4_address}:${local.immich_ports.webui}
			}
    EOT
  }
}

output "metrics_addresses" {
  description = "Prometheus metrics of the api and the job worker, only reachable inside the cluster"
  value = {
    api  = "${incus_instance.immich.ipv4_address}:${local.immich_ports.api_metrics}"
    jobs = "${incus_instance.immich.ipv4_address}:${local.immich_ports.jobs_metrics}"
  }
}
