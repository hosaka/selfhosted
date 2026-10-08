variable "slskd_version" {
  type    = string
  default = "0.26.0"
}

resource "incus_storage_volume" "slskd_data" {
  name = "slskd-data"
  pool = "linstor"

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "slskd" {
  name = "slskd"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:slskd/slskd:${var.slskd_version}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/app"
      pool   = incus_storage_volume.slskd_data.pool
      source = incus_storage_volume.slskd_data.name
    }
  }

  device {
    name = "media"
    type = "disk"
    properties = {
      path   = "/data/media"
      pool   = var.media_pool
      source = var.media_source
    }
  }

  config = {
    "environment.SLSKD_NO_AUTH"              = "true"
    "environment.SLSKD_NO_HTTPS"             = "true"
    "environment.SLSKD_REMOTE_CONFIGURATION" = "false"
    "environment.SLSKD_HTTP_PORT"            = "5030"
    "environment.SLSKD_SLSK_LISTEN_PORT"     = "50300"
    # use a socks5 proxy so the incoming connections go through FRP
    # instead of peers trying to connect to the server IP
    "environment.SLSKD_SLSK_PROXY_ENABLED"  = "true"
    "environment.SLSKD_SLSK_PROXY_ADDRESS"  = "frp.${var.public_domain}"
    "environment.SLSKD_SLSK_PROXY_PORT"     = "41080"
    "environment.SLSKD_SLSK_PROXY_USERNAME" = var.config.slsk_proxy_username
    "environment.SLSKD_SLSK_PROXY_PASSWORD" = sensitive(var.config.slsk_proxy_password)
    "environment.SLSKD_SLSK_USERNAME"       = var.config.slsk_username
    "environment.SLSKD_SLSK_PASSWORD"       = sensitive(var.config.slsk_password)
    # todo: when shared storage is available
    # these subdirectories must exists under MEDIA_DOWNLOADS_SOULSEEK_PATH/
    # "environment.SLSKD_DOWNLOADS_DIR"  = "/data/media/downloads/soulseek/downloads"
    # "environment.SLSKD_INCOMPLETE_DIR" = "/data/media/downloads/soulseek/incomplete"
    # uncomment the next line and the corresponding volume mount to enable sharing
    # "environment.SLSKD_SHARED_DIR" = "/data/media/collection/music"
    # "environment.SLSKD_UMASK" = var.config.umask
  }
}
