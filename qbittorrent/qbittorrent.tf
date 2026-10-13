locals {
  qbittorrent_ports = {
    webui = 8080
  }
}

resource "incus_storage_volume" "qbittorrent_data" {
  name = "qbittorrent-data"
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
  image    = "ghcr:hotio/qbittorrent:release-${var.versions.qbittorrent}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.qbittorrent_data.pool
      source = incus_storage_volume.qbittorrent_data.name
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
    content            = sensitive(var.secrets.wg0_conf)
    target_path        = "/config/wireguard/wg0.conf"
    mode               = "0600"
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    # Wireguard runs inside the container, the module has to be loaded on the host.
    "linux.kernel_modules"                          = "wireguard"
    "linux.sysctl.net.ipv4.conf.all.src_valid_mark" = "1"
    "linux.sysctl.net.ipv6.conf.all.disable_ipv6"   = "1"

    # Give the container an explicit, smaller capability set, Docker’s default set plus net_admin,
    # so capsh lists the capabilities individually in order for `init-wireguard/run` to execute correctly.
    #
    # Incus bind-mounts /etc/resolv.conf from outside the rootfs, so container root can't write it, but
    # `init-wireguard/run` overwrites it to keep DNS inside the tunnel, cover it with a writable copy.
    # This can't be done with a `file` because files are only pushed after the instance starts, and
    # "oci.entrypoint" only runs as PID 1, which s6 requires.
    "raw.lxc" = <<-EOT
      lxc.cap.drop =
      lxc.cap.keep = chown dac_override fowner fsetid kill setgid setuid setpcap net_bind_service net_raw sys_chroot mknod audit_write setfcap net_admin
      lxc.hook.mount = /bin/sh -c 'cp "$LXC_ROOTFS_MOUNT/etc/resolv.conf" "$LXC_ROOTFS_MOUNT/run/resolv.conf" && mount --bind "$LXC_ROOTFS_MOUNT/run/resolv.conf" "$LXC_ROOTFS_MOUNT/etc/resolv.conf"'
    EOT

    "environment.VPN_ENABLED"           = "true"
    "environment.VPN_PROVIDER"          = var.vpn_provider
    "environment.VPN_AUTO_PORT_FORWARD" = "true"
    # todo: set back to "true" once wtfismyip.com resolves again
    "environment.VPN_HEALTHCHECK_ENABLED" = "false"
    "environment.TZ"                      = var.timezone

    "user.access_interface" = "eth1"
  }
}

resource "incus_instance" "qbitmanage" {
  name = "qbitmanage"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:hotio/qbitmanage:release-${var.versions.qbitmanage}"

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
    content = templatefile("${path.module}/qbitmanage.yml.tpl", {
      qbittorrent_host = "${incus_instance.qbittorrent.ipv4_address}:${local.qbittorrent_ports.webui}"
    })
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
    "environment.TZ" = var.timezone

    "user.access_interface" = "eth1"
  }
}

output "probes" {
  value = [
    "https://qbit.${var.private_domain}/",
  ]
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
