public_domain = ""
private_domain = ""

cluster = {
  name = "incus-cluster"

  nic-1 = "ens18"
  nic-2 = "enp5s0"
  nvme-1 = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0"
  nvme-2 = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1"

  node-1 = {
    target = "incus-1"
  }
  node-2 = {
    target = "incus-2"
  }
  node-3 = {
    target = "incus-3"
  }
}

services = {
  gateway = "10.10.0.1"
  linstor = {
    ipv4 = "10.10.0.5"
  }
}

