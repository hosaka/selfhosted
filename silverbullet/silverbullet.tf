locals {
  silverbullet_ports = {
    webui = 3000
  }

  silverbullet_url = "https://silver.${var.public_domain}"
  public_url       = "https://${var.public_domain}${var.public_prefix}"
  authelia_url     = "https://auth.${var.public_domain}"

  // this is actually undocumented and might well break in next releases
  silverbullet_authentication = sensitive(jsonencode({
    revision = 1
    enabled  = true
    active = {
      providerId    = uuidv5("url", local.authelia_url)
      issuer        = local.authelia_url
      centralOrigin = local.silverbullet_url
      clientId      = var.secrets.oidc_client_id
      clientSecret  = var.secrets.oidc_client_secret
      buttonLabel   = "Sign in with Authelia"
    }
  }))
}

resource "incus_storage_volume" "silverbullet_data" {
  name = "silverbullet-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "silverbullet" {
  name = "silverbullet"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:silverbulletmd/silverbullet:${var.versions.silverbullet}-slim"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.silverbullet_data.pool
      source = incus_storage_volume.silverbullet_data.name
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.silverbullet.nic
  }

  file {
    content     = local.silverbullet_authentication
    target_path = "/data/authentication.json"
    mode        = "0600"
    uid         = 1000
    gid         = 1000
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.entrypoint"       = "/bin/sh -c 'while [ ! -f /data/spaces.json ]; do sleep 1; done; exec /sbin/tini -- /docker-entrypoint.sh'"
    "environment.NO_COLOR" = "1"
  }

  exec = {
    "00-setup" = {
      command = [
        "/bin/sh", "-c",
        "[ -f /data/spaces.json ] || /silverbullet setup /data --admin \"admin:$SB_ADMIN_PASSWORD\" --space Private --at /",
      ]
      environment = {
        SB_ADMIN_PASSWORD = sensitive(var.secrets.admin_password)
      }
      working_dir = "/data"
      uid         = 1000
      gid         = 1000
      trigger     = "once"
    }
  }
}

resource "null_resource" "silverbullet_restart" {
  triggers = {
    authentication = nonsensitive(sha1(local.silverbullet_authentication))
    config         = sha1(jsonencode(incus_instance.silverbullet.config))
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.silverbullet.name}"
  }
}

output "probes" {
  value = [
    "${local.silverbullet_url}/.instance",
    "${local.public_url}/",
  ]
}

output "backups" {
  value = {
    silverbullet = {
      volumes = {
        (incus_storage_volume.silverbullet_data.name) = {}
      }
    }
  }
}

output "ingress" {
  value = {
    name       = "silverbullet"
    caddy_apex = <<-EOT
			handle / {
				redir * ${var.public_prefix}/ 302
			}
			handle /robots.txt {
				respond <<TXT
					User-agent: *
					Disallow:
					Sitemap: ${local.public_url}/sitemap.xml
					TXT 200
			}
			handle {
				reverse_proxy ${var.addresses.silverbullet.ipv4}:${local.silverbullet_ports.webui}
			}
    EOT
    caddy      = <<-EOT
			silver.${var.public_domain} {
				reverse_proxy ${var.addresses.silverbullet.ipv4}:${local.silverbullet_ports.webui}
			}
    EOT
  }
}
