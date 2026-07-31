variable "wakapi_version" {
  type    = string
  default = "2.17.5"
}

resource "incus_storage_volume" "wakapi_data" {
  name = "wakapi-data"
  pool = var.storage

  config = {
    "initial.uid" = "65532"
    "initial.gid" = "65532"
  }
}

resource "incus_instance" "wakapi" {
  name = "wakapi"
  type = "container"

  target   = var.target
  profiles = var.profiles
  image    = "ghcr:muety/wakapi:${var.wakapi_version}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/app/data"
      pool   = var.storage
      source = incus_storage_volume.wakapi_data.name
    }
  }

  config = {
    "environment.WAKAPI_PUBLIC_URL"                     = "https://waka.${var.public_domain}"
    "environment.WAKAPI_DB_NAME"                        = "/app/data/wakapi_db.db"
    "environment.WAKAPI_PASSWORD_SALT"                  = "${sensitive(var.config.password_salt)}"
    "environment.WAKAPI_INSECURE_COOKIES"               = "false"
    "environment.WAKAPI_ALLOW_SIGNUP"                   = "false"
    "environment.WAKAPI_DISABLE_FRONTPAGE"              = "true"
    "environment.WAKAPI_OIDC_ALLOW_SIGNUP"              = "false"
    "environment.WAKAPI_OIDC_PROVIDERS_0_NAME"          = "authelia"
    "environment.WAKAPI_OIDC_PROVIDERS_0_DISPLAY_NAME"  = "Authelia"
    "environment.WAKAPI_OIDC_PROVIDERS_0_CLIENT_ID"     = "${var.config.oidc_client_id}"
    "environment.WAKAPI_OIDC_PROVIDERS_0_CLIENT_SECRET" = "${sensitive(var.config.oidc_client_secret)}"
    "environment.WAKAPI_OIDC_PROVIDERS_0_ENDPOINT"      = "https://auth.${var.public_domain}"
  }
}

