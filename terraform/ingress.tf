variable "caddy_version" {
  type    = string
  default = "2.11.4"
}

variable "frpc_version" {
  type    = string
  default = "0.69.1"
}

resource "incus_instance" "caddy" {
  name     = "caddy"
  type     = "container"
  profiles = [incus_profile.default.name, incus_profile.replicated.name]
  image    = "ghcr:hotio/caddy:release-${var.caddy_version}"
}

resource "incus_instance" "frpc" {
  name     = "frpc"
  type     = "container"
  profiles = [incus_profile.default.name, incus_profile.replicated.name]
  image    = "ghcr:fatedier/frpc:v${var.frpc_version}"

  file {
    content = templatefile("${path.module}/frpc/frpc.toml.tpl", {
      frp_server_addr = var.frp_server_addr
      frp_auth_token  = var.frp_auth_token
    })
    target_path = "/etc/frp/frpc.toml"
    uid         = 0
    gid         = 0
    mode        = "0600"

    create_directories = true
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /etc/frp/frpc.toml ]; do sleep 1; done; exec /usr/bin/frpc --config /etc/frp/frpc.toml'"
  }
}

