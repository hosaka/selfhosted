locals {
  # NUT's uid and gid in the container
  nut_id = 3493

  # the driver reports low battery, which makes upsmon power off the cluster
  low_battery = {
    charge  = 40   # percent
    runtime = 1200 # seconds
  }

  # longest cluster-poweroff waits for the other members
  member_timeout = 900

  nut_ports = {
    upsd = 3493
  }

  incus_conf = "/etc/incus"

  lan_gateway = split("/", var.gateway)[0]
  lan_prefix  = split("/", var.gateway)[1]

  nut_conf = <<-EOT
    MODE=standalone
  EOT

  ups_conf = <<-EOT
    maxretry = 3

    [ups]
      driver = usbhid-ups
      port = auto
      vendorid = ${var.usb.vendorid}
      productid = ${var.usb.productid}
      ignorelb
      override.battery.charge.low = ${local.low_battery.charge}
      override.battery.runtime.low = ${local.low_battery.runtime}
  EOT

  # upsmon reads it on localhost, PeaNUT over the LAN
  upsd_conf = <<-EOT
    LISTEN 127.0.0.1 ${local.nut_ports.upsd}
    LISTEN ${var.address} ${local.nut_ports.upsd}
  EOT

  upsd_users = <<-EOT
    [upsmon]
      password = ${random_password.upsmon.result}
      upsmon primary
  EOT

  upsmon_conf = <<-EOT
    MONITOR ups@localhost 1 upsmon ${random_password.upsmon.result} primary
    MINSUPPLIES 1
    SHUTDOWNCMD "/usr/local/sbin/cluster-poweroff"
    POWERDOWNFLAG "/etc/killpower"
  EOT

  poweroff_script = templatefile("${path.module}/cluster-poweroff.sh.tpl", {
    self         = var.target
    self_address = trimprefix(var.cluster_address, "https://")
    incus_conf   = local.incus_conf
    timeout      = local.member_timeout
  })
}

# upsmon logs in to upsd with it, both run in the container
resource "random_password" "upsmon" {
  length  = 32
  special = false
}

resource "incus_certificate" "ups" {
  name        = "ups"
  type        = "client"
  description = "NUT, powers off the cluster members through the IncusOS API"
  certificate = file("${path.module}/ups.crt")
  restricted  = false
}

# Runs the driver for the UPS and powers off the cluster on low battery.
resource "incus_instance" "nut" {
  name    = "nut"
  type    = "container"
  project = "internal"

  target   = var.target
  profiles = ["default"]
  image    = "images:debian/trixie/cloud"

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "lan"
      hwaddr  = "02:02:e6:52:a2:44"
    }
  }

  device {
    name = "ups"
    type = "usb"
    properties = {
      vendorid  = var.usb.vendorid
      productid = var.usb.productid
      gid       = local.nut_id
      mode      = "0660"
    }
  }

  file {
    content     = local.nut_conf
    target_path = "/etc/nut/nut.conf"
    uid         = 0
    gid         = local.nut_id
    mode        = "0640"
  }

  file {
    content     = local.ups_conf
    target_path = "/etc/nut/ups.conf"
    uid         = 0
    gid         = local.nut_id
    mode        = "0640"
  }

  file {
    content     = local.upsd_conf
    target_path = "/etc/nut/upsd.conf"
    uid         = 0
    gid         = local.nut_id
    mode        = "0640"
  }

  file {
    content     = sensitive(local.upsd_users)
    target_path = "/etc/nut/upsd.users"
    uid         = 0
    gid         = local.nut_id
    mode        = "0640"
  }

  file {
    content     = sensitive(local.upsmon_conf)
    target_path = "/etc/nut/upsmon.conf"
    uid         = 0
    gid         = local.nut_id
    mode        = "0640"
  }

  file {
    content     = local.poweroff_script
    target_path = "/usr/local/sbin/cluster-poweroff"
    mode        = "0755"
  }

  file {
    content            = var.cluster_certificate
    target_path        = "${local.incus_conf}/cluster.crt"
    mode               = "0644"
    create_directories = true
  }

  file {
    content            = file("${path.module}/ups.crt")
    target_path        = "${local.incus_conf}/client.crt"
    mode               = "0644"
    create_directories = true
  }

  file {
    content            = sensitive(file("${path.module}/ups.key"))
    target_path        = "${local.incus_conf}/client.key"
    mode               = "0600"
    create_directories = true
  }

  config = {
    "boot.autostart"          = true
    "boot.autostart.priority" = 100
    "boot.stop.priority"      = -200

    "cloud-init.network-config" = <<-EOT
      version: 2
      ethernets:
        eth0:
          addresses: [${var.address}/${local.lan_prefix}]
          routes: [{ to: 0.0.0.0/0, via: ${local.lan_gateway} }]
          nameservers: { addresses: [${local.lan_gateway}] }
    EOT
    "cloud-init.user-data" = templatefile("${path.module}/user-data.yml.tpl", {
      nut_id = local.nut_id
    })
  }

  wait_for {
    type = "cloud-init"
  }

  depends_on = [incus_certificate.ups]
}

# NUT's services fail until their config is pushed after the start, and only read it when they start
resource "null_resource" "nut_restart" {
  provisioner "local-exec" {
    command = "incus restart --project ${incus_instance.nut.project} ${incus_instance.nut.name}"
  }

  lifecycle {
    replace_triggered_by = [incus_instance.nut]
  }
}
