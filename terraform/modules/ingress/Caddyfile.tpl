{
	email ${cf_api_email}
	acme_dns cloudflare ${cf_api_token}
	# acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
	skip_install_trust

	servers {
		listener_wrappers {
			proxy_protocol {
				timeout 5s
				# PROXY protocol provided by FRP container (cannot use private_ranges here, only cidrs)
				# remote_host var will be set to a real user IP (X-Forwarded-For is set as well)
				allow 192.168.0.0/16 172.16.0.0/12 10.0.0.0/8 127.0.0.1/8
				fallback_policy reject
			}
			tls
		}
		trusted_proxies static private_ranges
		trusted_proxies_strict
	}
}

# public
${public_domain} {
	handle {
		respond 404
	}
	handle_path /web/* {
		file_server browse {
			root /srv/web
		}
	}
	handle_path /sh/dotinstall {
		reverse_proxy forgejo:3000
		rewrite * /hosaka/.dotfiles/raw/branch/main/.local/bin/dotinstall
	}
	handle_path /public.pgp {
		reverse_proxy forgejo:3000
		rewrite * /hosaka.gpg
	}
	handle_path /void/* {
		reverse_proxy forgejo:3000
		rewrite * /api/packages/hosaka/generic/vast-packages/{path}
	}
}

# tunnel
frp.${private_domain} {
	reverse_proxy frpc:7400
}
frp.${public_domain} {
	reverse_proxy frp.${public_domain}:7500
}

# files
mirror.${private_domain}, mirror.${public_domain} {
	handle_path /voidlinux* {
		root * /srv/voidrepo
		file_server browse {
			hide .partial
		}
	}
	respond 404
}
http://switch.${private_domain} {
	file_server browse {
		root /srv/switch
	}
}

# services
auth.${public_domain} {
	reverse_proxy authelia:9091
}
users.${private_domain} {
	reverse_proxy lldap:17170
}
jellyfin.${private_domain} {
	reverse_proxy jellyfin:8096
}
seerr.${private_domain} {
	reverse_proxy jellyseerr:5055
}
radarr.${private_domain} {
	reverse_proxy radarr:7878
}
sonarr.${private_domain} {
	reverse_proxy sonarr:8989
}
prowlarr.${private_domain} {
	reverse_proxy prowlarr:9696
}
navidrome.${private_domain}, navidrome.${public_domain} {
	reverse_proxy navidrome:4533
}
lidarr.${private_domain} {
	reverse_proxy lidarr:8686
}
kavita.${private_domain} {
	encode gzip
	reverse_proxy kavita:5000
}
nzb.${private_domain} {
	reverse_proxy sabnzbd:8080
}
slskd.${private_domain} {
	reverse_proxy slskd:5030
}
qbit.${private_domain} {
	reverse_proxy qbit:8080
}
immich.${private_domain}, immich.${public_domain} {
	reverse_proxy immich:2283
}
paperless.${private_domain}, paperless.${public_domain} {
	reverse_proxy paperless:8000
	@admin {
		path /admin*
		not remote_ip private_ranges
	}
	respond @admin "401 - {remote_host} is not an allowed IP" 401
}
atuin.${private_domain}, atuin.${public_domain} {
	reverse_proxy atuin:8888
}
vaultwarden.${private_domain}, vaultwarden.${public_domain} {
	encode zstd gzip

	header {
		# enable HTTP Strict Transport Security (HSTS)
		Strict-Transport-Security "max-age=31536000; preload"
		# disable enable cross-site filter (XSS)
		X-XSS-Protection "0"
		# disallow sniffing of X-Content-Type-Options
		X-Content-Type-Options "nosniff"
		# disallow the site to be rendered within a frame (clickjacking protection)
		X-Frame-Options "SAMEORIGIN"
		# prevent search engines from indexing
		X-Robots-Tag "none"
		# remove server name
		-Server
	}

	# allow access to the admin interface only from local networks
	@admin {
		path /admin*
		not remote_ip private_ranges
	}
	respond @admin "401 - {remote_host} is not an allowed IP" 401

	# proxy everything to Rocket
	reverse_proxy vaultwarden:80 {
		# send the true remote IP to Rocket, so fail2ban can ban correct IP from the log
		header_up X-Real-IP {remote_host}
	}
}
gotify.${private_domain}, gotify.${public_domain} {
	reverse_proxy gotify:80
}
hass.${private_domain} {
	reverse_proxy homeassistant:8123
}
frigate.${private_domain} {
	reverse_proxy frigate:5000
}

## Forgejo
code.${public_domain} {
	reverse_proxy forgejo-anubis:8923 {
		header_up X-Real-IP {remote_host}
		header_up X-Http-Version {http.request.proto}
	}
}
code.${private_domain} {
	reverse_proxy forgejo:3000
}

## Snikket
chat.${public_domain}, groups.chat.${public_domain}, share.chat.${public_domain} {
	handle_path /.well-known/acme-challenge/* {
		root * /var/www/acme-challenge
		file_server
	}

	# Prosody endpoints on the chat and share*/upload domain
	@prosody path /upload* /admin_api* /invites_api* /invites_bootstrap* /http-bind* /xmpp-websocket* /.well-known/host-meta /.well-known/host-meta.json
	handle @prosody {
		reverse_proxy snikket:5280
	}

	# everything else goes to web portal
	handle {
		reverse_proxy snikket-web:5765
	}
}

search.${private_domain}, search.${public_domain} {
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
		reverse_proxy searxng:8080 {
			header_up X-Forwarded-Port {http.request.port}
			header_up X-Forwarded-Proto {http.request.scheme}
			header_up X-Real-IP {remote_host}
		}
	}
}
grafana.${private_domain}, grafana.${public_domain} {
	reverse_proxy grafana:3000
}
ffs.${public_domain} {
	reverse_proxy syncstorage:8000
}
whoami.${private_domain}, whoami.${public_domain} {
	forward_auth authelia:9091 {
		uri /api/authz/forward-auth
		copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
	}
	reverse_proxy whoami:80
}
waka.${private_domain}, waka.${public_domain} {
	reverse_proxy wakapi:3000
}
