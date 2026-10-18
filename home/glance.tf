locals {
  glance_ports = {
    webui = 8080
  }

  # The services Glance has widgets for, and whether they need an API key.
  known_services = {
    prometheus = false
    sonarr     = true
    radarr     = true
    lidarr     = true
    prowlarr   = true
  }

  # Usable services
  services = {
    for name, service in var.services : name => service
    if !local.known_services[name] || service.api_key != null
  }

  glance_config = templatefile("${path.module}/glance.yml.tpl", {
    public_domain     = var.public_domain
    private_domain    = var.private_domain
    has               = { for name, _ in local.known_services : name => contains(keys(local.services), name) }
    addr              = { for name, service in local.services : name => service.address }
    storage_sources   = join("|", var.storage.sources)
    backup_repository = var.backups.repository
    backup_offset     = var.backups.schedule == null ? null : format("%sh%sm", split(" ", var.backups.schedule)[1], split(" ", var.backups.schedule)[0])
    weather_location  = replace(regex("[^/]+$", var.timezone), "_", " ") # the city part of the timezone, e.g. Asia/Tokyo -> Tokyo
  })

  # styles shared by the custom-api widgets
  glance_css = file("${path.module}/glance.css")

  # Secrets reach glance.yml as ${VAR} references that glance fills in from its environment.
  glance_environment = merge(
    { "environment.TZ" = var.timezone },
    { for name, service in local.services : "environment.${upper(name)}_API_KEY" => sensitive(service.api_key) if service.api_key != null },
  )
}

resource "incus_instance" "glance" {
  name = "glance"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "docker:glanceapp/glance:v${var.versions.glance}"

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.glance.nic
  }

  file {
    content            = local.glance_config
    target_path        = "/app/config/glance.yml"
    mode               = "0644"
    create_directories = true
  }

  file {
    content            = local.glance_css
    target_path        = "/app/assets/glance.css"
    mode               = "0644"
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = merge(local.glance_environment, {
    # files are uploaded after the start, and glance refuses an assets path that doesn't exist yet
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /app/config/glance.yml ] || [ ! -f /app/assets/glance.css ]; do sleep 1; done; exec /app/glance --config /app/config/glance.yml'"
  })
}

resource "null_resource" "glance_restart" {
  triggers = {
    config      = sha1(local.glance_config)
    css         = sha1(local.glance_css)
    environment = nonsensitive(sha1(jsonencode(local.glance_environment)))
  }

  provisioner "local-exec" {
    command = "incus exec glance -- /app/glance --config /app/config/glance.yml config:validate && incus restart glance"
  }

  depends_on = [incus_instance.glance]
}

output "probes" {
  value = [
    "https://home.${var.public_domain}/api/healthz",
  ]
}

output "ingress" {
  value = {
    name  = "home"
    caddy = <<-EOT
			home.${var.public_domain} {
				# the health check for the probe, manifest and static files for web app installs
				@protected not path /api/healthz /manifest.json /static/*

				forward_auth @protected ${var.forward_auth} {
					uri /api/authz/forward-auth
				}

				reverse_proxy ${var.addresses.glance.ipv4}:${local.glance_ports.webui}
			}
    EOT
  }
}
