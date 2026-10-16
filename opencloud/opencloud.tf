locals {
  opencloud_ports = {
    webui = 9200
  }

  opencloud_url      = "https://cloud.${var.public_domain}"
  authelia_url       = "https://auth.${var.public_domain}"
  oidc_client_scopes = "openid profile email groups opencloud offline_access"

  opencloud_data_path        = "/var/lib/opencloud"
  opencloud_files_path       = "/data"
  opencloud_config_path      = "/etc/opencloud"
  opencloud_init_config_path = "${local.opencloud_data_path}/config"

  opencloud_csp = yamlencode({
    directives = {
      "child-src"       = ["'self'"]
      "connect-src"     = ["'self'", "blob:", local.authelia_url]
      "default-src"     = ["'none'"]
      "font-src"        = ["'self'"]
      "frame-ancestors" = ["'self'"]
      "frame-src"       = ["'self'", "blob:", local.authelia_url]
      "img-src"         = ["'self'", "data:", "blob:"]
      "manifest-src"    = ["'self'"]
      "media-src"       = ["'self'"]
      "object-src"      = ["'self'", "blob:"]
      "script-src"      = ["'self'", "'unsafe-inline'", local.authelia_url]
      "style-src"       = ["'self'", "'unsafe-inline'", "blob:"]
      "worker-src"      = ["'self'", "blob:"]
    }
  })

  # roles come from the OIDC groups claim
  opencloud_proxy = yamlencode({
    role_assignment = {
      driver = "oidc"
      oidc_role_mapper = {
        role_claim = "groups"
        role_mapping = [
          { role_name = "admin", claim_value = var.admin_group },
          { role_name = "user", claim_value = var.user_group },
        ]
      }
    }
  })
}

resource "incus_storage_volume" "opencloud_data" {
  name = "opencloud-data"
  pool = "linstor"

  config = merge({
    # opencloud user in the image
    "initial.uid" = "1000"
    "initial.gid" = "1000"
  }, var.snapshots)
}

resource "incus_instance" "opencloud" {
  name = "opencloud"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:opencloudeu/opencloud-rolling:${var.versions.opencloud}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = local.opencloud_data_path
      pool   = incus_storage_volume.opencloud_data.pool
      source = incus_storage_volume.opencloud_data.name
    }
  }

  device {
    name = "storage"
    type = "disk"
    properties = {
      path   = local.opencloud_files_path
      pool   = var.storage_pool
      source = var.storage_source
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = "10:66:6a:66:55:4a"
    }
  }

  file {
    content     = local.opencloud_csp
    target_path = "${local.opencloud_config_path}/csp.yaml"
    mode        = "0644"
  }

  file {
    content     = local.opencloud_proxy
    target_path = "${local.opencloud_config_path}/proxy.yaml"
    mode        = "0644"
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    # `opencloud init` generates the secrets and ids once on the data volume so
    # they outlive the rootfs on upgrades, quietly to keep the admin password out of the console log
    "oci.entrypoint" = join(" ", [
      "/bin/sh -c 'while [ ! -f ${local.opencloud_config_path}/csp.yaml ] || [ ! -f ${local.opencloud_config_path}/proxy.yaml ]; do sleep 1; done;",
      "[ -f ${local.opencloud_init_config_path}/opencloud.yaml ] || opencloud init -q --config-path ${local.opencloud_init_config_path};",
      "ln -sf ${local.opencloud_init_config_path}/opencloud.yaml ${local.opencloud_config_path}/opencloud.yaml;",
      "exec opencloud server'",
    ])

    "environment.OC_URL"                         = local.opencloud_url
    "environment.OC_BASE_DATA_PATH"              = local.opencloud_data_path
    "environment.OC_CONFIG_DIR"                  = local.opencloud_config_path
    "environment.OC_LOG_LEVEL"                   = "info"  # defaults to error, silent after the start
    "environment.OC_INSECURE"                    = "false" # keep `opencloud init` from prompting for certificates
    "environment.PROXY_TLS"                      = "false" # caddy terminates tls
    "environment.PROXY_CSP_CONFIG_FILE_LOCATION" = "${local.opencloud_config_path}/csp.yaml"
    "environment.STORAGE_USERS_POSIX_ROOT"       = local.opencloud_files_path
    "environment.FRONTEND_CHECK_FOR_UPDATES"     = "false"
    "environment.OC_ADD_RUN_SERVICES"            = "notifications"

    # https://www.authelia.com/integration/openid-connect/clients/opencloud/
    "environment.OC_OIDC_ISSUER"                        = local.authelia_url
    "environment.OC_EXCLUDE_RUN_SERVICES"               = "idp" # authelia replaces the built-in identity provider
    "environment.PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD" = "jwt"
    "environment.PROXY_OIDC_REWRITE_WELLKNOWN"          = "true"
    "environment.PROXY_AUTOPROVISION_ACCOUNTS"          = "true"
    "environment.PROXY_AUTOPROVISION_CLAIM_USERNAME"    = "preferred_username"
    "environment.PROXY_AUTOPROVISION_CLAIM_EMAIL"       = "email"
    "environment.PROXY_AUTOPROVISION_CLAIM_DISPLAYNAME" = "name"
    "environment.PROXY_AUTOPROVISION_CLAIM_GROUPS"      = "opencloud_groups" # only the opencloud_* groups, see authelia

    # roles only come from the groups claim, see proxy.yaml
    "environment.GRAPH_ASSIGN_DEFAULT_USER_ROLE"       = "false"
    "environment.WEBFINGER_WEB_OIDC_CLIENT_ID"         = var.secrets.oidc_client_id
    "environment.WEBFINGER_WEB_OIDC_CLIENT_SCOPES"     = local.oidc_client_scopes
    "environment.WEBFINGER_ANDROID_OIDC_CLIENT_ID"     = var.secrets.oidc_apps_client_id
    "environment.WEBFINGER_ANDROID_OIDC_CLIENT_SCOPES" = local.oidc_client_scopes
    "environment.WEBFINGER_IOS_OIDC_CLIENT_ID"         = var.secrets.oidc_apps_client_id
    "environment.WEBFINGER_IOS_OIDC_CLIENT_SCOPES"     = local.oidc_client_scopes
    "environment.WEBFINGER_DESKTOP_OIDC_CLIENT_ID"     = var.secrets.oidc_apps_client_id
    "environment.WEBFINGER_DESKTOP_OIDC_CLIENT_SCOPES" = local.oidc_client_scopes

    "environment.NOTIFICATIONS_SMTP_HOST"       = var.secrets.smtp_host
    "environment.NOTIFICATIONS_SMTP_PORT"       = var.smtp_port
    "environment.NOTIFICATIONS_SMTP_ENCRYPTION" = var.smtp_encryption
    "environment.NOTIFICATIONS_SMTP_SENDER"     = coalesce(var.smtp_sender, "OpenCloud <cloud@${var.public_domain}>")
    "environment.NOTIFICATIONS_SMTP_USERNAME"   = sensitive(var.secrets.smtp_username)
    "environment.NOTIFICATIONS_SMTP_PASSWORD"   = sensitive(var.secrets.smtp_password)

    "user.access_interface" = "eth1"
  }
}

resource "null_resource" "opencloud_restart" {
  triggers = {
    config = nonsensitive(sha1(jsonencode(incus_instance.opencloud.config)))
    files  = sha1(join("\n", [local.opencloud_csp, local.opencloud_proxy]))
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.opencloud.name}"
  }
}

output "probes" {
  value = [
    "${local.opencloud_url}/status.php",
  ]
}

output "backups" {
  value = {
    opencloud = {
      volumes = {
        (incus_storage_volume.opencloud_data.name) = {
          excludes = ["thumbnails"]
        }
      }
    }
  }
}

output "ingress" {
  value = {
    name  = "opencloud"
    caddy = <<-EOT
			cloud.${var.public_domain} {
				reverse_proxy ${incus_instance.opencloud.ipv4_address}:${local.opencloud_ports.webui}
			}
    EOT
  }
}
