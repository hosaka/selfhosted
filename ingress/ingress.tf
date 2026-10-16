locals {
  frpc_ports = {
    webui     = 7400
    dashboard = 7500
  }

  caddy_ports = {
    http    = 80
    https   = 443
    metrics = 2020
  }

  caddyfile = join("\n", concat(
    [templatefile("${path.module}/Caddyfile.tpl", {
      cf_api_email   = sensitive(var.secrets.caddy_cf_api_email)
      cf_api_token   = sensitive(var.secrets.caddy_cf_api_token)
      public_domain  = var.public_domain
      private_domain = var.private_domain
      services       = var.services
      metrics_port   = local.caddy_ports.metrics
    })],
  ))

  frpc_toml = templatefile("${path.module}/frpc.toml.tpl", {
    frp_server_addr           = var.secrets.frp_server_addr
    frp_auth_token            = sensitive(var.secrets.frp_auth_token)
    frps_dashboard_secret_key = sensitive(var.secrets.frps_dashboard_secret_key)
    caddy_ip                  = incus_instance.caddy.ipv4_address
    caddy_ports               = local.caddy_ports
    frpc_ports                = local.frpc_ports
    services                  = var.services
  })
}

resource "incus_instance" "frpc" {
  name = "frpc"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:fatedier/frpc:v${var.versions.frpc}"

  lifecycle {
    prevent_destroy = true
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = "10:66:6a:eb:f7:d4"
    }
  }

  file {
    content            = local.frpc_toml
    target_path        = "/etc/frp/frpc.toml"
    mode               = "0600"
    create_directories = true
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

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "caddy" {
  name = "caddy"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:hotio/caddy:release-${var.versions.caddy}"

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

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = "10:66:6a:9b:06:fe"
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

output "backups" {
  value = {
    caddy = {
      volumes = {
        (incus_storage_volume.caddy_data.name) = {
          excludes = ["Caddyfile", "caddy/locks", "caddy/last_clean.json", "caddy/autosave.json"]
        }
      }
    }
  }
}

output "caddy_metrics_address" {
  description = "Caddy's prometheus metrics endpoint, only reachable inside the cluster"
  value       = "${incus_instance.caddy.ipv4_address}:${local.caddy_ports.metrics}"
}

output "frps_metrics_address" {
  description = "The frps dashboard and its /metrics through frpc's stcp visitor, only reachable inside the cluster"
  value       = "${incus_instance.frpc.ipv4_address}:${local.frpc_ports.dashboard}"
}
