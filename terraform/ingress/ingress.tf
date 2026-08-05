variable "frpc_version" {
  type    = string
  default = "0.70.1"
}

variable "caddy_version" {
  type    = string
  default = "2.11.4"
}

variable "whoami_version" {
  type    = string
  default = "1.12.0"
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
    content = templatefile("${path.module}/frpc.toml.tpl", {
      public_domain   = var.public_domain
      frp_server_addr = var.config.frp_server_addr
      frp_auth_token  = sensitive(var.config.frp_auth_token)
    })
    target_path        = "/etc/frp/frpc.toml"
    mode               = "0600"
    create_directories = true
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /etc/frp/frpc.toml ]; do sleep 1; done; exec /usr/bin/frpc --config /etc/frp/frpc.toml'"
  }
}

resource "incus_storage_volume" "caddy_data" {
  name = "caddy-data"
  pool = "remote"
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

  file {
    content = templatefile("${path.module}/Caddyfile.tpl", {
      public_domain  = var.public_domain
      private_domain = var.private_domain
      cf_api_email   = sensitive(var.config.caddy_cf_api_email)
      cf_api_token   = sensitive(var.config.caddy_cf_api_token)
    })
    target_path = "/config/Caddyfile"
    mode        = "0600"
  }
}

resource "incus_instance" "whoami" {
  name = "whoami"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:traefik/whoami:v${var.whoami_version}"
}

