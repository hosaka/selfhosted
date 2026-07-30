version: 2
ethernets:
  eth0:
    dhcp4: true
  eth1:
    addresses:
      - ${ipv4}
    routes:
      - to: 0.0.0.0/0
        via: ${gateway}
    nameservers:
      addresses: [${gateway}]
