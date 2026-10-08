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
    name       = string
    domains    = optional(list(string), [])
    caddy      = optional(string, "")
    caddy_apex = optional(string, "")
    frpc       = optional(string, "")
  }))
  default = []
}

locals {
  frpc_ports = {
    webui = 7400
  }

  caddy_ports = {
    http  = 80
    https = 443
  }

  public_domains = distinct(concat(
    [var.public_domain],
    flatten([for s in var.services : s.domains])
  ))

  caddyfile = join("\n", concat(
    [templatefile("${path.module}/Caddyfile.tpl", {
      cf_api_email  = sensitive(var.config.caddy_cf_api_email)
      cf_api_token  = sensitive(var.config.caddy_cf_api_token)
      public_domain = var.public_domain
      services      = var.services
    })],
  ))

  frpc_toml = templatefile("${path.module}/frpc.toml.tpl", {
    frp_server_addr = var.config.frp_server_addr
    frp_auth_token  = sensitive(var.config.frp_auth_token)
    caddy_ip        = incus_instance.caddy.ipv4_address
    caddy_ports     = local.caddy_ports
    frpc_ports      = local.frpc_ports
    public_domains  = local.public_domains
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
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /etc/frp/frpc.toml ]; do sleep 1; done; exec /usr/bin/frpc --config /etc/frp/frpc.toml'"

    "user.access_interface" = "eth1"
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
      hwaddr  = "10:66:6a:08:77:c0"
      network = "lan"
    }
  }

  # required for any services using var.private_domain
  # add the ipv4 on this NIC to DHCP leases on the router and point
  # all the *.${var.private_domain} traffic to this address in order
  # to correctly resolve LAN-only access
  device {
    name = "eth1"
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
    "environment.TZ"        = var.timezone
    "user.access_interface" = "eth1"
  }
}

resource "null_resource" "caddy_reload" {
  triggers = {
    caddyfile = nonsensitive(sha1(local.caddyfile))
  }

  provisioner "local-exec" {
    command = "incus exec caddy -- caddy reload --config /config/Caddyfile"
  }

  depends_on = [incus_instance.caddy]
}

resource "null_resource" "frpc_reload" {
  triggers = {
    config = nonsensitive(sha1(local.frpc_toml))
  }

  provisioner "local-exec" {
    command = "incus exec frpc -- frpc reload --config /etc/frp/frpc.toml"
  }

  depends_on = [incus_instance.frpc]
}
