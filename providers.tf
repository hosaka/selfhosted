provider "incus" {
  accept_remote_certificate = true

  default_remote = var.cluster.name

  remote {
    name = var.cluster.name
  }

  remote {
    name     = "docker"
    address  = "https://docker.io"
    protocol = "oci"
    public   = true
  }

  remote {
    name     = "ghcr"
    address  = "https://ghcr.io"
    protocol = "oci"
    public   = true
  }

  remote {
    name     = "codeberg"
    address  = "https://codeberg.org"
    protocol = "oci"
    public   = true
  }
}

# Talks to LLDAP API through Caddy, password managed via LDAP directly
provider "lldap" {
  http_url = "https://users.${var.private_domain}"
  ldap_url = "ldap://${module.auth.lldap_address}"
  password = var.secrets.auth.lldap_user_pass
  base_dn  = module.auth.lldap_base_dn
}
