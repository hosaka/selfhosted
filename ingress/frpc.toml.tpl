serverAddr = "${frp_server_addr}"
serverPort = 7000
auth.token = "${frp_auth_token}"

webServer.addr = "0.0.0.0"
webServer.port = ${frpc_ports.webui}

# we have a bunch of UDP proxies and need a bigger connection pool
# the frps side also sets maxPoolCount for clients, this should be less than the max
transport.poolCount = 10

# to allow proxies to get real user IP
# see: https://gofrp.org/en/docs/features/common/realip/
# transport.proxyProtocolVersion = "v2"

loginFailExit = false

log.to = "/tmp/frpc.log"
log.level = "info"
log.maxDays = 3

[[proxies]]
name = "https"
type = "tcp"
localIP = "${caddy_ip}"
localPort = ${caddy_ports.https}
remotePort = ${caddy_ports.https}
transport.proxyProtocolVersion = "v2"

[[proxies]]
name = "http"
type = "tcp"
localIP = "${caddy_ip}"
localPort = ${caddy_ports.http}
remotePort = ${caddy_ports.http}
transport.proxyProtocolVersion = "v2"

%{ for s in services ~}
${s.frpc}
%{ endfor ~}
