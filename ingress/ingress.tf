locals {
  frpc_ports = {
    webui     = 7400
    dashboard = 7500
    metrics   = 7501
  }

  caddy_ports = {
    http    = 80
    https   = 443
    metrics = 2020
  }

  # same shape as the other modules' ingress outputs,
  # all attributes have to be set since it skips var.services defaults
  ingress = {
    name       = "frp"
    caddy_apex = ""
    caddy      = <<-EOT
			# frps dashboard on the VPS, through frpc's stcp visitor
			frp.${var.public_domain} {
				reverse_proxy ${var.addresses.frpc.ipv4}:${local.frpc_ports.dashboard}
			}

			# frpc's own web UI has no login so we restrict it to private ips
			frp.${var.private_domain} {
				import private
				reverse_proxy ${var.addresses.frpc.ipv4}:${local.frpc_ports.webui}
			}
    EOT
  }

  # each match is the site's address and the line after its opening brace
  private_site_pattern = "(?m)^[ \\t]*([^\\s{#][^{#\\n]*\\.${replace(var.private_domain, ".", "\\.")})[ \\t]*\\{[ \\t]*\\n([^\\n]*)$"

  unguarded_private_sites = flatten([
    for s in concat([local.ingress], var.services) : [
      for site in regexall(local.private_site_pattern, s.caddy) : trimspace(site[0])
      if trimspace(site[1]) != "import private" && alltrue([
        for address in split(",", site[0]) : endswith(trimspace(address), ".${var.private_domain}")
      ])
    ]
  ])

  caddyfile = join("\n", concat(
    [templatefile("${path.module}/Caddyfile.tftpl", {
      acme_email     = sensitive(var.secrets.acme_email)
      desec_token    = sensitive(var.desec_token)
      public_domain  = var.public_domain
      private_domain = var.private_domain
      services       = concat([local.ingress], var.services)
      metrics_port   = local.caddy_ports.metrics
    })],
  ))

  frpc_toml = templatefile("${path.module}/frpc.toml.tftpl", {
    frp_server_addr           = var.secrets.frp_server_addr
    frp_auth_token            = sensitive(var.secrets.frp_auth_token)
    frps_dashboard_secret_key = sensitive(var.secrets.frps_dashboard_secret_key)
    caddy_ip                  = var.addresses.caddy.ipv4
    caddy_ports               = local.caddy_ports
    frpc_ports                = local.frpc_ports
    services                  = var.services
  })
}

resource "incus_instance" "frpc" {
  name = "frpc"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:fatedier/frpc:v${var.versions.frpc}"

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.frpc.nic
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
  profiles = ["default", "oci"]
  image    = "ghcr:hosaka/caddy-desec:${var.versions.caddy}"

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
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.caddy.nic
  }

  file {
    content            = local.caddyfile
    target_path        = "/etc/caddy/site/Caddyfile"
    mode               = "0600"
    create_directories = true
  }

  config = {
    "environment.TZ"            = var.timezone
    "environment.XDG_DATA_HOME" = "/config"
    "oci.entrypoint"            = "/bin/sh -c 'while [ ! -f /etc/caddy/site/Caddyfile ]; do sleep 1; done; exec caddy run --config /etc/caddy/site/Caddyfile --adapter caddyfile'"
  }

  lifecycle {
    precondition {
      condition     = length(local.unguarded_private_sites) == 0
      error_message = "Sites only on the private domain have to start with `import private`, frps makes them reachable from the internet otherwise: ${join(", ", local.unguarded_private_sites)}"
    }
  }
}

resource "null_resource" "caddy_reload" {
  triggers = {
    caddyfile = nonsensitive(sha1(local.caddyfile))
  }

  provisioner "local-exec" {
    command = "incus exec caddy -- caddy reload --config /etc/caddy/site/Caddyfile"
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
          excludes = ["caddy/locks", "caddy/last_clean.json", "caddy/autosave.json"]
        }
      }
    }
  }
}

output "caddy_metrics_address" {
  description = "Caddy's prometheus metrics endpoint, only reachable inside the cluster"
  value       = "${var.addresses.caddy.ipv4}:${local.caddy_ports.metrics}"
}

output "frps_metrics_address" {
  description = "The frps metrics endpoint, only reachable inside the cluster"
  value       = "${var.addresses.frpc.ipv4}:${local.frpc_ports.metrics}"
}
