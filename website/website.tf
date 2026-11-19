locals {
  website_ports = {
    http = 80
  }

  # seconds between the builder's checks for a new commit
  poll_interval = 60

  public_url = "https://${var.public_domain}${var.public_prefix}"

  website_caddyfile = <<-EOT
		{
			auto_https off
		}

		:${local.website_ports.http} {
			@site path ${var.public_prefix} ${var.public_prefix}/*
			handle @site {
				root * /srv/website
				encode zstd gzip
				file_server
			}
			handle {
				error 404
			}

			handle_errors 404 {
				root * /srv/website
				rewrite * ${var.public_prefix}/404.html
				file_server
			}
		}
  EOT
}

resource "incus_storage_volume" "website" {
  name   = "website"
  pool   = "local"
  target = var.target
}

# Polls Forgejo for new commits, builds them with Zola and swaps the published build, see build.sh.
resource "incus_instance" "website_build" {
  name = "website-build"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:getzola/zola:v${var.versions.zola}-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/srv/website"
      pool   = incus_storage_volume.website.pool
      source = incus_storage_volume.website.name
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.website_build.nic
  }

  file {
    content     = file("${path.module}/build.sh")
    target_path = "/usr/local/bin/website-build"
    mode        = "0755"
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.REPOSITORY" = "${var.forgejo_address}/${var.repository}.git"
    "environment.BRANCH"     = var.branch
    "environment.BASE_URL"   = local.public_url
    "environment.OUTPUT"     = "/srv/website"
    "environment.LINK"       = trimprefix(var.public_prefix, "/")
    "oci.entrypoint"         = "/bin/sh -c 'while [ ! -x /usr/bin/git ]; do sleep 1; done; while :; do /usr/local/bin/website-build; sleep ${local.poll_interval}; done'"
  }

  exec = {
    "00-git" = {
      command = ["/sbin/apk", "add", "--no-cache", "--quiet", "git"]
      trigger = "once"
    }
  }
}

resource "null_resource" "website_build_restart" {
  triggers = {
    config = sha1(jsonencode(incus_instance.website_build.config))
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.website_build.name}"
  }
}

resource "incus_instance" "website" {
  name = "website"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "docker:caddy:${var.versions.caddy}-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path     = "/srv/website"
      pool     = incus_storage_volume.website.pool
      source   = incus_storage_volume.website.name
      readonly = "true"
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.website.nic
  }

  file {
    content     = local.website_caddyfile
    target_path = "/config/Caddyfile"
    mode        = "0644"
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /config/Caddyfile ]; do sleep 1; done; exec caddy run --config /config/Caddyfile --adapter caddyfile'"
  }
}

resource "null_resource" "website_restart" {
  triggers = {
    caddyfile = sha1(local.website_caddyfile)
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.website.name}"
  }
}

output "probes" {
  value = [
    "${local.public_url}/",
  ]
}

output "ingress" {
  value = {
    name       = "website"
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
			handle ${var.public_prefix}* {
				reverse_proxy ${var.addresses.website.ipv4}:${local.website_ports.http}
			}
    EOT
  }
}
