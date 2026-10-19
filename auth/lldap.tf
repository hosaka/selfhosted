locals {
  lldap_base_dn = coalesce(var.lldap_base_dn, "dc=${join(",dc=", split(".", var.public_domain))}")

  lldap_ports = {
    ldap  = 3890
    webui = 17170
  }
}

resource "incus_storage_volume" "lldap_data" {
  name = "lldap-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

# users and groups are managed by the users module
resource "incus_instance" "lldap" {
  name = "lldap"
  type = "container"

  target   = var.target
  profiles = ["default", "oci", "datastore"]
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

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.lldap.nic
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
  }
}
