variable "qbittorrent_version" {
  type    = string
  default = "5.2.3"
}

variable "qbitmanage_version" {
  type    = string
  default = "4.11.0"
}

locals {
  qbittorrent_ports = {
    webui = 8080
  }

  qbitmanage_config = templatefile("${path.module}/qbitmanage.yml.tpl", {
    qbittorrent_host = "${incus_instance.qbittorrent.ipv4_address}:${local.qbittorrent_ports.webui}"
  })
}

resource "incus_storage_volume" "qbittorrent_config" {
  name = "qbittorrent-config"
  pool = "linstor"

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "qbittorrent" {
  name = "qbittorrent"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:hotio/qbittorrent:release-${var.qbittorrent_version}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.qbittorrent_config.pool
      source = incus_storage_volume.qbittorrent_config.name
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

  file {
    content            = sensitive(var.config.wg0_conf)
    target_path        = "/config/wireguard/wg0.conf"
    mode               = "0600"
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    # wireguard runs inside the container, the module has to be loaded on the host
    "linux.kernel_modules"                          = "wireguard"
    "linux.sysctl.net.ipv4.conf.all.src_valid_mark" = "1"
    "linux.sysctl.net.ipv6.conf.all.disable_ipv6"   = "1"

    "environment.VPN_ENABLED"  = "true"
    "environment.VPN_PROVIDER" = var.config.vpn_provider
    # anything coming in from outside these networks is dropped by the VPN killswitch
    "environment.VPN_LAN_NETWORK"         = var.config.vpn_lan_network
    "environment.VPN_AUTO_PORT_FORWARD"   = "true"
    "environment.VPN_HEALTHCHECK_ENABLED" = "true"
    "environment.TZ"                      = var.timezone

    # files are pushed after the instance starts, the VPN must not come up without wg0.conf
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /config/wireguard/wg0.conf ]; do sleep 1; done; exec /init'"

    "user.access_interface" = "eth1"
  }
}

resource "incus_instance" "qbitmanage" {
  name = "qbitmanage"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:hotio/qbitmanage:release-${var.qbitmanage_version}"

  device {
    name = "media"
    type = "disk"
    properties = {
      path   = "/data/media"
      pool   = var.media_pool
      source = var.media_source
    }
  }

  file {
    content            = local.qbitmanage_config
    target_path        = "/config/config.yml"
    mode               = "0644"
    uid                = 1000
    gid                = 1000
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /config/config.yml ]; do sleep 1; done; exec /init'"
    "environment.TZ" = var.timezone

    "user.access_interface" = "eth1"
  }
}

output "ingress" {
  value = {
    name  = "qbittorrent"
    caddy = <<-EOT
    qbit.${var.private_domain} {
      reverse_proxy ${incus_instance.qbittorrent.ipv4_address}:${local.qbittorrent_ports.webui}
    }
    EOT
  }
}
