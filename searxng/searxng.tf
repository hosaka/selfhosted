locals {
  searxng_ports = {
    webui  = 8080
    valkey = 6379
  }
}

resource "incus_instance" "searxng" {
  name = "searxng"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:searxng/searxng:${var.versions.searxng}"

  file {
    content            = file("${path.module}/settings.yml")
    target_path        = "/etc/searxng/settings.yml"
    mode               = "0600"
    create_directories = true
  }

  file {
    content = templatefile("${path.module}/limiter.toml.tpl", {
      trusted_proxies = var.trusted_proxies
    })
    target_path        = "/etc/searxng/limiter.toml"
    mode               = "0600"
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.SEARXNG_SECRET"     = sensitive(var.secrets.secret)
    "environment.SEARXNG_BASE_URL"   = "https://search.${var.public_domain}"
    "environment.SEARXNG_VALKEY_URL" = "valkey://${incus_instance.searxng_valkey.ipv4_address}:${local.searxng_ports.valkey}/0"

    "user.access_interface" = "eth1"
  }
}

resource "incus_storage_volume" "searxng_cache" {
  name   = "searxng-cache"
  pool   = "local"
  target = var.target

  config = {
    # valkey user in alpine
    "initial.uid" = "999"
    "initial.gid" = "1000"
  }
}

resource "incus_instance" "searxng_valkey" {
  name = "searxng-valkey"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:valkey/valkey:${var.versions.cache}"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.searxng_cache.pool
      source = incus_storage_volume.searxng_cache.name
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
    # snapshot to disk every 30s if at least one key changed, as in searxng's own compose
    "oci.entrypoint" = "tini -- docker-entrypoint.sh valkey-server --save 30 1 --loglevel warning"

    "user.access_interface" = "eth0"
  }
}

output "ingress" {
  value = {
    name = "searxng"
    domains = [
      "search.${var.public_domain}"
    ]
    caddy = <<-EOT
			search.${var.private_domain}, search.${var.public_domain} {
				log {
					output discard
				}

				@api {
					path /config
					path /healthz
					path /stats/errors
					path /stats/checker
				}

				@static {
					path /static/*
				}

				@notstatic {
					not path /static/*
				}

				@imageproxy {
					path /image_proxy
				}

				@notimageproxy {
					not path /image_proxy
				}

				header {
					# enable HTTP Strict Transport Security (HSTS)
					Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
					# disable enable cross-site filter (XSS)
					X-XSS-Protection "0"
					# prevent some browsers from MIME-sniffing a response away from the declared Content-Type
					X-Content-Type-Options "nosniff"
					# disable some features
					Permissions-Policy "accelerometer=(),ambient-light-sensor=(),autoplay=(),camera=(),encrypted-media=(),focus-without-user-activation=(),geolocation=(),gyroscope=(),magnetometer=(),microphone=(),midi=(),payment=(),picture-in-picture=(),speaker=(),sync-xhr=(),usb=(),vr=()"
					# disable some features (legacy)
					Feature-Policy "accelerometer 'none';ambient-light-sensor 'none'; autoplay 'none';camera 'none';encrypted-media 'none';focus-without-user-activation 'none'; geolocation 'none';gyroscope 'none';magnetometer 'none';microphone 'none';midi 'none';payment 'none';picture-in-picture 'none'; speaker 'none';sync-xhr 'none';usb 'none';vr 'none'"
					# referer
					Referrer-Policy "no-referrer"
					# prevent search engines from indexing
					X-Robots-Tag "noindex, noarchive, nofollow"
					# remove server header
					-Server
				}

				header @api {
					Access-Control-Allow-Methods "GET, OPTIONS"
					Access-Control-Allow-Origin "*"
				}

				header @static {
					# Cache
					Cache-Control "public, max-age=31536000"
					defer
				}

				header @notstatic {
					# No Cache
					Cache-Control "no-cache, no-store"
					Pragma "no-cache"
				}

				# CSP (see http://content-security-policy.com/ )
				header @imageproxy {
					Content-Security-Policy "default-src 'none'; img-src 'self' data:"
				}

				header @notimageproxy {
					Content-Security-Policy "upgrade-insecure-requests; default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; form-action 'self' https://github.com/searxng/searxng/issues/new; font-src 'self'; frame-ancestors 'self'; base-uri 'self'; connect-src 'self' https://overpass-api.de; img-src 'self' data: https://*.tile.openstreetmap.org; frame-src https://www.youtube-nocookie.com https://player.vimeo.com https://www.dailymotion.com https://www.deezer.com https://www.mixcloud.com https://w.soundcloud.com https://embed.spotify.com"
				}

				handle {
					encode zstd gzip
					reverse_proxy ${incus_instance.searxng.ipv4_address}:${local.searxng_ports.webui} {
						header_up X-Forwarded-Port {http.request.port}
						header_up X-Forwarded-Proto {http.request.scheme}
						header_up X-Real-IP {remote_host}
					}
				}
			}
    EOT
  }
}
