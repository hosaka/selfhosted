variable "slskd_version" {
  type    = string
  default = "0.26.0"
}

locals {
  slskd_ports = {
    webui  = 5030
    listen = 50300
  }

  slskd_dirs = {
    downloads  = "/data/media/downloads/soulseek/downloads"
    incomplete = "/data/media/downloads/soulseek/incomplete"
    shared     = "/data/media/collection/music"
  }
}

resource "incus_storage_volume" "slskd_data" {
  name = "slskd-data"
  pool = "linstor"

  config = {
    "initial.uid" = var.config.puid
    "initial.gid" = var.config.pgid
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

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "incusbr0"
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      network = "meshbr0"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.uid" = var.config.puid
    "oci.gid" = var.config.pgid

    "environment.SLSKD_NO_AUTH"              = "true"
    "environment.SLSKD_NO_HTTPS"             = "true"
    "environment.SLSKD_REMOTE_CONFIGURATION" = "false"
    "environment.SLSKD_HTTP_PORT"            = local.slskd_ports.webui
    "environment.SLSKD_SLSK_LISTEN_PORT"     = local.slskd_ports.listen
    # use a socks5 proxy so the incoming connections go through FRP
    # instead of peers trying to connect to the server IP
    "environment.SLSKD_SLSK_PROXY_ENABLED"  = "true"
    "environment.SLSKD_SLSK_PROXY_ADDRESS"  = "frp.${var.public_domain}"
    "environment.SLSKD_SLSK_PROXY_PORT"     = "41080"
    "environment.SLSKD_SLSK_PROXY_USERNAME" = var.config.slsk_proxy_username
    "environment.SLSKD_SLSK_PROXY_PASSWORD" = sensitive(var.config.slsk_proxy_password)
    "environment.SLSKD_SLSK_USERNAME"       = var.config.slsk_username
    "environment.SLSKD_SLSK_PASSWORD"       = sensitive(var.config.slsk_password)
    "environment.SLSKD_DOWNLOADS_DIR"       = local.slskd_dirs.downloads
    "environment.SLSKD_INCOMPLETE_DIR"      = local.slskd_dirs.incomplete
    "environment.SLSKD_SHARED_DIR"          = local.slskd_dirs.shared
    "environment.SLSKD_UMASK"               = var.config.umask

    # slskd refuses to start when the dirs are missing
    "oci.entrypoint" = "/usr/bin/tini -- /bin/sh -c 'umask ${var.config.umask} && mkdir -p ${join(" ", values(local.slskd_dirs))} && exec /entrypoint.sh /slskd/slskd'"

    "user.access_interface" = "eth1"
  }
}

output "ingress" {
  value = {
    name = "slskd"

    caddy = <<-EOT
    slskd.${var.private_domain} {
      reverse_proxy ${incus_instance.slskd.ipv4_address}:${local.slskd_ports.webui}
    }
    EOT

    frpc = <<-EOT
    [[proxies]]
    name = "slskd-xfer"
    type = "tcp"
    localIP = "${incus_instance.slskd.ipv4_address}"
    localPort = ${local.slskd_ports.listen}
    remotePort = ${local.slskd_ports.listen}
    EOT
  }
}
