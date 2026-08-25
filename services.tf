locals {
  mesh_subnet = format("10.%d.%d.0/24", random_integer.meshbr0-v4-subnet-2.result, random_integer.meshbr0-v4-subnet-3.result)

  service_idx = {
    frpc   = 10
    caddy  = 11
    whoami = 12
  }

  service_ips = {
    for name, idx in local.service_idx : name => cidrhost(local.mesh_subnet, idx)
  }
}
