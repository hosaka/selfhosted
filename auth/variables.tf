variable "config" {
  type = object({
    # lldap
    lldap_base_dn    = string
    lldap_user_pass  = string
    lldap_jwt_secret = string
    lldap_key_seed   = string
    lldap_password   = string

    # authelia
    session_secret         = string
    storage_encryption_key = string
    smtp_address           = string
    smtp_username          = string
    smtp_password          = string
    smtp_sender            = string
    jwt_secret             = string
    db_name                = optional(string, "authelia")
    db_username            = optional(string, "postgres")
    db_password            = string

    # clients
    forgejo_client_id              = string
    forgejo_client_secret_hash     = string
    gotify_client_id               = string
    gotify_client_secret_hash      = string
    grafana_client_id              = string
    grafana_client_secret_hash     = string
    immich_client_id               = string
    immich_client_secret_hash      = string
    jellyfin_client_id             = string
    jellyfin_client_secret_hash    = string
    kavita_client_id               = string
    kavita_client_secret_hash      = string
    paperless_client_id            = string
    paperless_client_secret_hash   = string
    vaultwarden_client_id          = string
    vaultwarden_client_secret_hash = string
    wakapi_client_id               = string
    wakapi_client_secret_hash      = string
  })
}

variable "target" {
  type = string
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

