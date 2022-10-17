# From live Alpine Linux

- Configure network interfaces with DHCP and restart them.
- Configure OpenSSH to get a remote shell.

```
setup-interfaces -a -r
setup-apkrepos -1
apk add python3
setup-sshd -k "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIqQwgcXplAfUV/YeJC8FIpZgl0Hr86P35mj6qcnpEJC alex" openssh
```

# From Ansible
```
apk add e2fsprogs mdadm sgdisk gptfdisk grub-efi efibootmgr btrfs-progs dosfstools zfs zfs-lts lz4
```

# Power Management
- 1 WD Red 8TB drive consumes about 6W of power.
- At standby with all drives powered ON the consumption is 77W (default BIOS)
- At standby with all drives powered OFF the consumption is 45W (default BIOS)