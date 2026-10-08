[botdetection]
# caddy reaches searxng over the mesh, trust it so the client IP is taken from X-Forwarded-For / X-Real-IP
trusted_proxies = [
  '127.0.0.0/8',
  '::1',
  '${trusted_proxies}',
]

[botdetection.ip_limit]
# activate link_token method in the ip_limit method
link_token = true
