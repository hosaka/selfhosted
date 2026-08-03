variable "authelia_version" {
  type    = string
  default = "4.39.20"
}

variable "lldap_version" {
  type    = string
  default = "0.6.3"
}

resource "incus_instance" "authelia" {
  name = "authelia"
  type = "container"

  target   = var.target
  profiles = var.profiles
  image    = "ghcr:authelia/authelia:${var.authelia_version}"

  file {
    content = templatefile("${path.module}/configuration.yml.tpl", {
      public_domain  = var.public_domain
      private_domain = var.private_domain
      lldap_base_dn  = var.config.lldap_base_dn

      db_name                = var.config.db_name
      db_password            = sensitive(var.config.db_password)
      db_username            = var.config.db_username
      jwt_secret             = sensitive(var.config.jwt_secret)
      jwks_key               = sensitive(indent(10, trimspace(file("${path.module}/private.pem"))))
      ldap_password          = sensitive(var.config.ldap_password)
      session_secret         = sensitive(var.config.session_secret)
      smtp_address           = var.config.smtp_address
      smtp_password          = sensitive(var.config.smtp_password)
      smtp_sender            = var.config.smtp_sender
      smtp_username          = sensitive(var.config.smtp_username)
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

    target_path        = "/config/configuration.yml"
    mode               = "0600"
    create_directories = true
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /config/configuration.yml ]; do sleep 1; done; exec /app/entrypoint.sh'"
  }
}

resource "incus_storage_volume" "authelia_database" {
  name = "authelia-database"
  pool = var.storage
}

resource "incus_instance" "authelia_database" {
  name = "authelia-database"
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
      source = incus_storage_volume.authelia_database.name
    }
  }

  config = {
    "environment.POSTGRES_DB"       = var.config.db_name
    "environment.POSTGRES_USER"     = var.config.db_username
    "environment.POSTGRES_PASSWORD" = sensitive(var.config.db_password)
    "environment.PGTZ"              = var.timezone
  }
}

resource "incus_storage_volume" "authelia_valkey" {
  name = "authelia-valkey"
  pool = var.storage
}

resource "incus_instance" "authelia_valkey" {
  name = "authelia-valkey"
  type = "container"

  target   = var.target
  profiles = var.profiles
  image    = "docker:valkey/valkey:8-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = var.storage
      source = incus_storage_volume.authelia_valkey.name
    }
  }
}

resource "incus_storage_volume" "lldap_data" {
  name = "lldap-data"
  pool = var.storage
}

# todo: figure out how to create default authelia user/pwd with lldap_password_manager gruop
# probably using the lldap bootstrap.sh script as suggested in the readme
resource "incus_instance" "lldap" {
  name = "lldap"
  type = "container"

  target   = var.target
  profiles = var.profiles
  image    = "ghcr:lldap/lldap:v${var.lldap_version}-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = var.storage
      source = incus_storage_volume.lldap_data.name
    }
  }

  config = {
    "environment.LLDAP_LDAP_BASE_DN"   = var.config.lldap_base_dn
    "environment.LLDAP_LDAP_USER_PASS" = sensitive(var.config.lldap_user_pass)
    "environment.LLDAP_JWT_SECRET"     = sensitive(var.config.lldap_jwt_secret)
    "environment.LLDAP_KEY_SEED"       = sensitive(var.config.lldap_key_seed)
  }
}
