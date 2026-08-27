locals {
  mesh_subnet = format("10.%d.%d.0/24", random_integer.meshbr0-v4-subnet-2.result, random_integer.meshbr0-v4-subnet-3.result)

  service_idx = {
    frpc   = 10
    caddy  = 11
    whoami = 12
  }

  services = {
    for name, idx in local.service_idx : name => {
      ipv4 = cidrhost(local.mesh_subnet, idx)
      # that first 3 octets must match Incus's OUI
      mac = format("10:66:6a:%s", join(":", [
        for o in slice(split(".", cidrhost(local.mesh_subnet, idx)), 1, 4) : format("%02x", tonumber(o))
      ]))
    }
  }
}
