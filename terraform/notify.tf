variable "gotify_version" {
  type    = string
  default = "3.0.0"
}

variable "diun_version" {
  type    = string
  default = "4.33"
}

resource "incus_storage_volume" "gotify_data" {
  name = "gotify-data"
  pool = incus_storage_pool.remote.name
}

resource "incus_instance" "gotify" {
  name = "gotify"
  type = "container"

  target   = var.cluster.node-2.target
  profiles = [incus_profile.default.name]
  image    = "ghcr:gotify/server:${var.gotify_version}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/app/data"
      pool   = incus_storage_pool.remote.name
      source = incus_storage_volume.gotify_data.name
    }
  }

  config = {
    "environment.GOTIFY_OIDC_ENABLED"       = "true"
    "environment.GOTIFY_OIDC_ISSUER"        = "https://auth.${var.public_domain}"
    "environment.GOTIFY_OIDC_CLIENTID"      = "${var.auth_gotify_client_id}"
    "environment.GOTIFY_OIDC_CLIENTSECRET"  = "${var.auth_gotify_client_secret}"
    "environment.GOTIFY_OIDC_REDIRECTURL"   = "https://gotify.${var.public_domain}/auth/oidc/callback"
    "environment.GOTIFY_OIDC_AUTOREGISTER"  = "true"
    "environment.GOTIFY_OIDC_USERNAMECLAIM" = "preferred_username"
  }
}

resource "incus_storage_volume" "diun_data" {
  name = "diun-data"
  pool = incus_storage_pool.remote.name
}

resource "incus_instance" "diun" {
  name = "diun"
  type = "container"

  target   = var.cluster.node-2.target
  profiles = [incus_profile.default.name]
  image    = "ghcr:crazy-max/diun:${var.diun_version}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/app/data"
      pool   = incus_storage_pool.remote.name
      source = incus_storage_volume.diun_data.name
    }
  }

  file {
    content = templatefile("${path.module}/config/diun.config.yml", {
      public_domain   = var.public_domain
      frp_server_addr = var.frp_server_addr
      frp_auth_token  = var.frp_auth_token
    })
    target_path = "/config.yml"
    mode        = "0600"
  }

  config = {
    "environment.DIUN_NOTIF_GOTIFY_ENDPOINT"   = "http://${incus_instance.gotify.name}"
    "environment.DIUN_NOTIF_GOTIFY_TOKEN"      = "${var.diun_gotify_token}"
    "environment.DIUN_WATCH_WORKERS"           = "10"
    "environment.DIUN_WATCH_SCHEDULE"          = "0 */6 * * *"
    "environment.DIUN_REGOPTS_0_NAME"          = "docker.io"
    "environment.DIUN_REGOPTS_0_SELECTOR"      = "image"
    "environment.DIUN_REGOPTS_0_USERNAME"      = "${var.diun_dockerhub_username}"
    "environment.DIUN_REGOPTS_0_PASSWORD"      = "${var.diun_dockerhub_password}"
    "environment.DIUN_REGOPTS_1_NAME"          = "ghcr.io"
    "environment.DIUN_REGOPTS_1_SELECTOR"      = "image"
    "environment.DIUN_REGOPTS_1_USERNAME"      = "${var.diun_ghcr_username}"
    "environment.DIUN_REGOPTS_1_PASSWORD"      = "${var.diun_ghcr_password}"
    "environment.DIUN_PROVIDERS_FILE_FILENAME" = "/config.yml"
  }
}
