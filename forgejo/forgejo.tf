locals {
  forgejo_ports = {
    webui = 3000
    ssh   = 2222
    db    = 5432
  }

  forgejo_anubis_ports = {
    proxy = 8923
  }
}

resource "incus_instance" "forgejo_anubis" {
  name = "forgejo-anubis"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:techarohq/anubis:v${var.versions.anubis}"

  file {
    content            = file("${path.module}/anubis.yml")
    target_path        = "/data/botPolicies.yaml"
    mode               = "0600"
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.TARGET"           = "http://${incus_instance.forgejo.ipv4_address}:${local.forgejo_ports.webui}"
    "environment.SERVE_ROBOTS_TXT" = "true"
    "environment.DIFFICULTY"       = "6"

    "user.access_interface" = "eth1"
  }
}

resource "incus_storage_volume" "forgejo_data" {
  name = "forgejo-data"
  pool = "linstor"

  config = {
    "size"        = "24GiB"
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "forgejo" {
  name = "forgejo"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "codeberg:forgejo/forgejo:${var.versions.forgejo}-rootless"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/var/lib/gitea"
      pool   = incus_storage_volume.forgejo_data.pool
      source = incus_storage_volume.forgejo_data.name
    }
  }

  file {
    content = templatefile("${path.module}/app.ini.tpl", {
      public_domain = var.public_domain
      http_port     = local.forgejo_ports.webui
      ssh_port      = local.forgejo_ports.ssh

      db_name         = var.db_name
      db_username     = var.secrets.db_username
      db_password     = sensitive(var.secrets.db_password)
      db_host         = incus_instance.forgejo_database.ipv4_address
      smtp_address    = var.secrets.smtp_address
      smtp_port       = var.smtp_port
      mailer_from     = coalesce(var.mailer_from, "Code <noreply@code.${var.public_domain}>")
      mailer_user     = sensitive(var.secrets.mailer_user)
      mailer_password = sensitive(var.secrets.mailer_password)
      internal_token  = sensitive(var.secrets.internal_token)
      trusted_proxies = var.trusted_proxies
      secret_key      = sensitive(var.secrets.secret_key)
      lfs_jwt_secret  = sensitive(var.secrets.lfs_jwt_secret)
    })

    target_path        = "/var/lib/gitea/custom/conf/app.ini"
    uid                = 1000
    gid                = 1000
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/templates/custom/extra_links.tmpl")
    target_path        = "/var/lib/gitea/custom/templates/extra_links.tmpl"
    uid                = 1000
    gid                = 1000
    mode               = "0600"
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.USER_UID"  = "1000"
    "environment.USER_GID"  = "1000"
    "environment.GNUPGHOME" = "/var/lib/gitea/.gnupg"

    "user.access_interface" = "eth1"
  }

  exec = {
    "10-add-oauth" = {
      command = ["/bin/sh", "-c", <<-EOT
        forgejo admin auth add-oauth \
          --provider=openidConnect --name=Authelia \
          --key="$KEY" --secret="$SECRET" --auto-discover-url="$DISCOVERY" \
          --scopes=openid --scopes=email --scopes=profile --scopes=groups \
          --group-claim-name=groups --admin-group=forgejo_admin --skip-local-2fa || true
      EOT
      ]
      environment = {
        KEY       = var.secrets.oidc_client_id
        SECRET    = sensitive(var.secrets.oidc_client_secret)
        DISCOVERY = "https://auth.${var.public_domain}/.well-known/openid-configuration"
      }
      uid = 1000
      gid = 1000
    }
  }
}

resource "incus_storage_volume" "forgejo_db" {
  name = "forgejo-db"
  pool = "linstor"

  config = {
    # postgres user in alpine
    "initial.uid" = "70"
    "initial.gid" = "70"
  }
}

resource "incus_instance" "forgejo_database" {
  name = "forgejo-database"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:postgres:${var.versions.db}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/var/lib/postgresql"
      pool   = incus_storage_volume.forgejo_db.pool
      source = incus_storage_volume.forgejo_db.name
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "incusbr0"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.POSTGRES_DB"       = var.db_name
    "environment.POSTGRES_USER"     = var.secrets.db_username
    "environment.POSTGRES_PASSWORD" = sensitive(var.secrets.db_password)
    "environment.PGTZ"              = var.timezone

    "user.access_interface" = "eth0"
  }
}

output "ingress" {
  value = {
    name = "code"
    domains = [
      "code.${var.public_domain}"
    ]
    caddy_apex = <<-EOT
			handle_path /sh/dotinstall {
				reverse_proxy ${incus_instance.forgejo.ipv4_address}:${local.forgejo_ports.webui}
				rewrite * /hosaka/.dotfiles/raw/branch/main/.local/bin/dotinstall
			}
			handle_path /public.pgp {
				reverse_proxy ${incus_instance.forgejo.ipv4_address}:${local.forgejo_ports.webui}
				rewrite * /hosaka.gpg
			}
			handle_path /void/* {
				reverse_proxy ${incus_instance.forgejo.ipv4_address}:${local.forgejo_ports.webui}
				rewrite * /api/packages/hosaka/generic/vast-packages/{path}
			}
    EOT
    caddy      = <<-EOT
			code.${var.public_domain} {
				reverse_proxy ${incus_instance.forgejo_anubis.ipv4_address}:${local.forgejo_anubis_ports.proxy} {
					header_up X-Real-IP {remote_host}
					header_up X-Http-Version {http.request.proto}
				}
			}
			code.${var.private_domain} {
				reverse_proxy ${incus_instance.forgejo.ipv4_address}:${local.forgejo_ports.webui}
			}
    EOT
    frpc       = <<-EOT
      [[proxies]]
      name = "ssh-code"
      type = "tcpmux"
      multiplexer = "httpconnect"
      customDomains = ["git.${var.public_domain}"]
      localIP = "${incus_instance.forgejo.ipv4_address}"
      localPort = ${local.forgejo_ports.ssh}
    EOT
  }
}
