{
	email ${cf_api_email}
	acme_dns cloudflare ${cf_api_token}
	# acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
	skip_install_trust

	log {
		format json
	}

	# metrics per site
	metrics {
		per_host
	}

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

# prometheus metrics, stays inside the cluster
:${metrics_port} {
	metrics
}

# public
${public_domain} {
	log {
		hostnames ${public_domain} *.${public_domain} *.${private_domain}
		output stdout

		# headers and query strings may carry credentials so they get filtered
		format filter {
			wrap json
			request>headers delete
			resp_headers delete
			request>uri regexp "\?.*$" "?..."
		}
	}

	handle {
		respond 404
	}

%{ for s in services ~}
${s.caddy_apex}
%{ endfor ~}
}

%{ for s in services ~}
# ${s.name}
${s.caddy}
%{ endfor ~}
