serverAddr = "${frp_server_addr}"
serverPort = 7000
auth.token = "${frp_auth_token}"

webServer.addr = "0.0.0.0"
webServer.port = 7400

# we have a bunch of UDP proxies and need a bigger connection pool
# the frps side also sets maxPoolCount for clients, this should be less than the max
transport.poolCount = 10

# to allow proxies to get real user IP
# see: https://gofrp.org/en/docs/features/common/realip/
# transport.proxyProtocolVersion = "v2"

loginFailExit = false

[[proxies]]
name = "https-cluster"
type = "https"
customDomains = [${join(", ", [for s in services : format("%q", "${s.name}.${public_domain}") if s.public])}]
localIP = "${caddy_ip}"
localPort = 443
transport.proxyProtocolVersion = "v2"

[[proxies]]
name = "http-cluster"
type = "http"
customDomains = [${join(", ", [for s in services : format("%q", "${s.name}.${public_domain}") if s.public])}]
localIP = "${caddy_ip}"
localPort = 80
transport.proxyProtocolVersion = "v2"

%{ for s in services ~}
${s.frpc}
%{ endfor ~}
