variable "frpc_version" {
  type    = string
  default = "0.69.1"
}

variable "caddy_version" {
  type    = string
  default = "2.11.4"
}

variable "whoami_version" {
  type    = string
  default = "1.11.0"
}

resource "incus_instance" "frpc" {
  name     = "frpc"
  type     = "container"
  profiles = [incus_profile.default.name, incus_profile.replicated.name]
  image    = "ghcr:fatedier/frpc:v${var.frpc_version}"

  file {
    content = templatefile("${path.module}/frpc/frpc.toml.tpl", {
      public_domain = var.public_domain
      frp_server_addr = var.frp_server_addr
      frp_auth_token  = var.frp_auth_token
    })
    target_path = "/etc/frp/frpc.toml"
    uid         = 0
    gid         = 0
    mode        = "0600"
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /etc/frp/frpc.toml ]; do sleep 1; done; exec /usr/bin/frpc --config /etc/frp/frpc.toml'"
  }
}

resource "incus_storage_volume" "caddy_config" {
  name = "caddy_config"
  pool = incus_storage_pool.remote.name
}

resource "incus_instance" "caddy" {
  depends_on = [incus_storage_volume.caddy_config]

  name     = "caddy"
  type     = "container"
  profiles = [incus_profile.default.name, incus_profile.replicated.name]
  image    = "ghcr:hotio/caddy:release-${var.caddy_version}"

  device {
    name = "caddy_config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_pool.remote.name
      source = incus_storage_volume.caddy_config.name
    }
  }

  file {
    content = templatefile("${path.module}/caddy/Caddyfile.tpl", {
      public_domain = var.public_domain
      private_domain = var.private_domain
      caddy_cf_api_email = var.caddy_cf_api_email
      caddy_cf_api_token  = var.caddy_cf_api_token
    })
    target_path = "/config/Caddyfile"
    uid         = 0
    gid         = 0
    mode        = "0600"
  }
}

resource "incus_instance" "whoami" {
  name     = "whoami"
  image    = "ghcr:traefik/whoami:v${var.whoami_version}"
  profiles = [incus_profile.default.name]
}

