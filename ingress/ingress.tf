variable "frpc_version" {
  type    = string
  default = "0.70.1"
}

variable "caddy_version" {
  type    = string
  default = "2.11.4"
}

variable "services" {
  type = list(object({
    name   = string
    public = optional(bool, false)
    caddy  = string
  }))
  default = []
}

locals {
  caddyfile = join("\n", concat(
    [templatefile("${path.module}/Caddyfile.header.tpl", {
      cf_api_email = sensitive(var.config.caddy_cf_api_email)
      cf_api_token = sensitive(var.config.caddy_cf_api_token)
    })],
    [for s in var.services : s.caddy]
  ))

  frpc_toml = templatefile("${path.module}/frpc.toml.tpl", {
    public_domain   = var.public_domain
    caddy_ip        = incus_instance.caddy.ipv4_address
    frp_server_addr = var.config.frp_server_addr
    frp_auth_token  = sensitive(var.config.frp_auth_token)
    services        = var.services
  })
}

resource "incus_instance" "frpc" {
  name = "frpc"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:fatedier/frpc:v${var.frpc_version}"

  lifecycle {
    prevent_destroy = true
  }

  file {
    content            = local.frpc_toml
    target_path        = "/etc/frp/frpc.toml"
    mode               = "0600"
    create_directories = true
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "meshbr0"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /etc/frp/frpc.toml ]; do sleep 1; done; exec /usr/bin/frpc --config /etc/frp/frpc.toml'"
  }
}

resource "incus_storage_volume" "caddy_data" {
  name = "caddy-data"
  pool = "linstor"

  config = {
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "caddy" {
  name = "caddy"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:hotio/caddy:release-${var.caddy_version}"

  lifecycle {
    prevent_destroy = true
  }

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.caddy_data.pool
      source = incus_storage_volume.caddy_data.name
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "meshbr0"
    }
  }

  file {
    content     = local.caddyfile
    target_path = "/config/Caddyfile"
    mode        = "0600"
    uid         = 1000
    gid         = 1000
  }

  config = {
    "environment.TZ" = var.timezone
  }
}

resource "null_resource" "caddy_reload" {
  triggers = {
    caddyfile = sha1(local.caddyfile)
  }

  provisioner "local-exec" {
    command = "incus exec caddy -- caddy reload --config /config/Caddyfile"
  }

  depends_on = [incus_instance.caddy]
}

resource "null_resource" "frpc_reload" {
  triggers = {
    config = sha1(local.frpc_toml)
  }

  provisioner "local-exec" {
    command = "incus exec frpc -- frpc reload --config /etc/frp/frpc.toml"
  }

  depends_on = [incus_instance.frpc]
}
