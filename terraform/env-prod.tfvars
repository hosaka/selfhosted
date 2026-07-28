cluster = {
  name = "cluster"

  nic-1 = "eno1"
  nic-2 = "enp5s0"
  nvme-1 = ""
  nvme-2 = ""

  node-1 = {
    target = "node-1"
  }
  node-2 = {
    target = "node-2"
  }
  node-3 = {
    target = "node-3"
  }
}

services = {
  gateway = "10.10.1.1"
  linstor = {
    ipv4 = "10.10.1.10"
  }
}

