variable "authelia_version" {
  type    = string
  default = "4.39.20"
}

variable "lldap_version" {
  type    = string
  default = "0.6.3"
}

locals {
  authelia_config = templatefile("${path.module}/configuration.yml.tpl", {
    public_domain  = var.public_domain
    private_domain = var.private_domain

    db_address             = incus_instance.authelia_database.ipv4_address
    db_name                = var.config.db_name
    db_password            = sensitive(var.config.db_password)
    db_username            = var.config.db_username
    jwt_secret             = sensitive(var.config.jwt_secret)
    jwks_key               = sensitive(indent(10, trimspace(file("${path.module}/private.pem"))))
    lldap_address          = incus_instance.lldap.ipv4_address
    lldap_base_dn          = var.config.lldap_base_dn
    lldap_password         = sensitive(var.config.lldap_password)
    session_secret         = sensitive(var.config.session_secret)
    smtp_address           = var.config.smtp_address
    smtp_password          = sensitive(var.config.smtp_password)
    smtp_sender            = var.config.smtp_sender
    smtp_username          = sensitive(var.config.smtp_username)
    valkey_address         = incus_instance.authelia_valkey.ipv4_address
    storage_encryption_key = sensitive(var.config.storage_encryption_key)

    # clients
    forgejo_client_id              = var.config.forgejo_client_id
    forgejo_client_secret_hash     = var.config.forgejo_client_secret_hash
    gotify_client_id               = var.config.gotify_client_id
    gotify_client_secret_hash      = var.config.gotify_client_secret_hash
    grafana_client_id              = var.config.grafana_client_id
    grafana_client_secret_hash     = var.config.grafana_client_secret_hash
    immich_client_id               = var.config.immich_client_id
    immich_client_secret_hash      = var.config.immich_client_secret_hash
    jellyfin_client_id             = var.config.jellyfin_client_id
    jellyfin_client_secret_hash    = var.config.jellyfin_client_secret_hash
    kavita_client_id               = var.config.kavita_client_id
    kavita_client_secret_hash      = var.config.kavita_client_secret_hash
    paperless_client_id            = var.config.paperless_client_id
    paperless_client_secret_hash   = var.config.paperless_client_secret_hash
    vaultwarden_client_id          = var.config.vaultwarden_client_id
    vaultwarden_client_secret_hash = var.config.vaultwarden_client_secret_hash
    wakapi_client_id               = var.config.wakapi_client_id
    wakapi_client_secret_hash      = var.config.wakapi_client_secret_hash
  })
}

resource "incus_instance" "authelia" {
  name = "authelia"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:authelia/authelia:${var.authelia_version}"

  file {
    content            = local.authelia_config
    target_path        = "/config/configuration.yml"
    mode               = "0600"
    create_directories = true
  }

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
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /config/configuration.yml ]; do sleep 1; done; exec /app/entrypoint.sh'"

    "user.access_interface" = "eth0"
  }
}

resource "incus_storage_volume" "authelia_db" {
  name = "authelia-db"
  pool = "linstor"

  config = {
    # postgres user in alpine
    "initial.uid" = "70"
    "initial.gid" = "70"
  }
}

resource "incus_instance" "authelia_database" {
  name = "authelia-database"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:postgres:18-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/var/lib/postgresql"
      pool   = incus_storage_volume.authelia_db.pool
      source = incus_storage_volume.authelia_db.name
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

resource "incus_storage_volume" "authelia_cache" {
  name = "authelia-cache"
  pool = "linstor"

  config = {
    # valkey user in alpine
    "initial.uid" = "999"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "authelia_valkey" {
  name = "authelia-valkey"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:valkey/valkey:8-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.authelia_cache.pool
      source = incus_storage_volume.authelia_cache.name
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
    "user.access_interface" = "eth0"
  }
}

resource "incus_storage_volume" "lldap_data" {
  name = "lldap-data"
  pool = "linstor"

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

# todo: figure out how to create default authelia user/pwd with lldap_password_manager gruop
# probably using the lldap bootstrap.sh script as suggested in the readme
resource "incus_instance" "lldap" {
  name = "lldap"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:lldap/lldap:v${var.lldap_version}-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.lldap_data.pool
      source = incus_storage_volume.lldap_data.name
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "meshbr0"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.LLDAP_LDAP_BASE_DN"   = var.config.lldap_base_dn
    "environment.LLDAP_LDAP_USER_PASS" = sensitive(var.config.lldap_user_pass)
    "environment.LLDAP_JWT_SECRET"     = sensitive(var.config.lldap_jwt_secret)
    "environment.LLDAP_KEY_SEED"       = sensitive(var.config.lldap_key_seed)
    "environment.UID"                  = "1000"
    "environment.GID"                  = "1000"
    "environment.TZ"                   = var.timezone

    "user.access_interface" = "eth0"
  }
}

resource "null_resource" "authelia_restart" {
  triggers = {
    config = sha1(local.authelia_config)
  }

  provisioner "local-exec" {
    command = "incus exec authelia -- authelia validate-config --config /config/configuration.yml && incus restart authelia"
  }

  depends_on = [incus_instance.authelia]
}

output "ingress" {
  value = {
    name   = "auth"
    public = true
    caddy  = <<-EOT
      auth.${var.public_domain} {
        reverse_proxy ${incus_instance.authelia.ipv4_address}:9091
      }
      users.${var.private_domain} {
        reverse_proxy ${incus_instance.lldap.ipv4_address}:17170
      }
    EOT
  }
}
