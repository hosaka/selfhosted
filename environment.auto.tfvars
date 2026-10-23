timezone       = "Asia/Tokyo"
public_domain  = "hosaka.cc"
private_domain = "box.hosaka.cc"

cluster = {
  uplink  = "uplink"
  gateway = "10.10.0.1/24"

  node-1 = {
    ipv4_address = "10.10.0.101"
  }
  node-2 = {
    ipv4_address = "10.10.0.102"
  }
  node-3 = {
    ipv4_address = "10.10.0.103"
  }
  node-4 = {
    ipv4_address = "10.10.0.104"
  }
}

# OVN network
ovn = {
  # instance network, routed from the LAN through the OVN router
  subnet = "10.42.0.0/24"

  # addresses for ad-hoc instances, services get fixed ones below .200
  dhcp_range = "10.42.0.200-10.42.0.250"

  # LAN addresses, outside of the router DHCP pool (.100-.229)
  router = "10.10.0.240"
  central = {
    node-1 = "10.10.0.241"
    node-2 = "10.10.0.242"
    node-3 = "10.10.0.243"
  }

  # 2.5 GbE members, routed LAN traffic goes through the active gateway
  gateway_chassis = ["node-1", "node-2", "node-3"]
}

# UPS monitor on node-1. directly on the LAN, so it can reach every node
# while OVN goes down in an event of a shutdown
ups = {
  address = "10.10.0.250"
}
