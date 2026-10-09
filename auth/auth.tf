locals {
  lldap_base_dn = coalesce(var.lldap_base_dn, "dc=${join(",dc=", split(".", var.public_domain))}")

  authelia_ports = {
    api    = 9091
    db     = 5432
    valkey = 6379
  }

  lldap_ports = {
    ldap  = 3890
    webui = 17170
  }

  authelia_config = templatefile("${path.module}/configuration.yml.tpl", {
    public_domain  = var.public_domain
    private_domain = var.private_domain

    db_address             = incus_instance.authelia_database.ipv4_address
    db_name                = var.db_name
    db_password            = sensitive(var.secrets.db_password)
    db_username            = var.secrets.db_username
    jwt_secret             = sensitive(var.secrets.jwt_secret)
    jwks_key               = sensitive(indent(10, trimspace(file("${path.module}/private.pem"))))
    lldap_address          = incus_instance.lldap.ipv4_address
    lldap_port             = local.lldap_ports.ldap
    lldap_base_dn          = local.lldap_base_dn
    lldap_password         = sensitive(var.secrets.lldap_password)
    session_secret         = sensitive(var.secrets.session_secret)
    smtp_address           = var.secrets.smtp_address
    smtp_password          = sensitive(var.secrets.smtp_password)
    smtp_sender            = coalesce(var.smtp_sender, "Authelia <auth@${var.public_domain}>")
    smtp_username          = sensitive(var.secrets.smtp_username)
    valkey_address         = incus_instance.authelia_valkey.ipv4_address
    valkey_port            = local.authelia_ports.valkey
    storage_encryption_key = sensitive(var.secrets.storage_encryption_key)

    # clients
    forgejo_client_id              = var.secrets.forgejo_client_id
    forgejo_client_secret_hash     = var.secrets.forgejo_client_secret_hash
    gotify_client_id               = var.secrets.gotify_client_id
    gotify_client_secret_hash      = var.secrets.gotify_client_secret_hash
    grafana_client_id              = var.secrets.grafana_client_id
    grafana_client_secret_hash     = var.secrets.grafana_client_secret_hash
    immich_client_id               = var.secrets.immich_client_id
    immich_client_secret_hash      = var.secrets.immich_client_secret_hash
    jellyfin_client_id             = var.secrets.jellyfin_client_id
    jellyfin_client_secret_hash    = var.secrets.jellyfin_client_secret_hash
    kavita_client_id               = var.secrets.kavita_client_id
    kavita_client_secret_hash      = var.secrets.kavita_client_secret_hash
    paperless_client_id            = var.secrets.paperless_client_id
    paperless_client_secret_hash   = var.secrets.paperless_client_secret_hash
    vaultwarden_client_id          = var.secrets.vaultwarden_client_id
    vaultwarden_client_secret_hash = var.secrets.vaultwarden_client_secret_hash
    wakapi_client_id               = var.secrets.wakapi_client_id
    wakapi_client_secret_hash      = var.secrets.wakapi_client_secret_hash
  })
}

resource "incus_instance" "authelia" {
  name = "authelia"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:authelia/authelia:${var.versions.authelia}"

  file {
    content            = local.authelia_config
    target_path        = "/config/configuration.yml"
    mode               = "0600"
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /config/configuration.yml ]; do sleep 1; done; exec /app/entrypoint.sh'"

    "user.access_interface" = "eth1"
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
  image    = "docker:postgres:${var.versions.db}"

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
    "environment.POSTGRES_DB"       = var.db_name
    "environment.POSTGRES_USER"     = var.secrets.db_username
    "environment.POSTGRES_PASSWORD" = sensitive(var.secrets.db_password)
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
  image    = "docker:valkey/valkey:${var.versions.cache}"

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
  profiles = ["default", "mesh"]
  image    = "ghcr:lldap/lldap:v${var.versions.lldap}-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.lldap_data.pool
      source = incus_storage_volume.lldap_data.name
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.LLDAP_LDAP_BASE_DN"   = local.lldap_base_dn
    "environment.LLDAP_LDAP_USER_PASS" = sensitive(var.secrets.lldap_user_pass)
    "environment.LLDAP_JWT_SECRET"     = sensitive(var.secrets.lldap_jwt_secret)
    "environment.LLDAP_KEY_SEED"       = sensitive(var.secrets.lldap_key_seed)
    "environment.UID"                  = "1000"
    "environment.GID"                  = "1000"
    "environment.TZ"                   = var.timezone

    "user.access_interface" = "eth1"
  }
}

resource "null_resource" "authelia_restart" {
  triggers = {
    config = nonsensitive(sha1(local.authelia_config))
  }

  provisioner "local-exec" {
    command = "incus exec authelia -- authelia validate-config --config /config/configuration.yml && incus restart authelia"
  }

  depends_on = [incus_instance.authelia]
}

output "ingress" {
  value = {
    name = "auth"
    domains = [
      "auth.${var.public_domain}"
    ]
    caddy = <<-EOT
			auth.${var.public_domain} {
				reverse_proxy ${incus_instance.authelia.ipv4_address}:${local.authelia_ports.api}
			}
			users.${var.private_domain} {
				reverse_proxy ${incus_instance.lldap.ipv4_address}:${local.lldap_ports.webui}
			}
    EOT
  }
}
