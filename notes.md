# From live Alpine Linux

- Configure network interfaces with DHCP and restart them.
- Configure OpenSSH to get a remote shell.

```
setup-interfaces -a -r
setup-sshd openssh
setup-apkrepos -c -f 
apk add python3
```

# From Ansible

- replace /etc/apk/repositories with edge pinned
- setup-hostname -n var.box_hostname
- setup-timezone -z var.box_timezone
- setup-ntp chrony
- yes | ROOTFS=btrfs setup-disk -m sys -s 0 /dev/sda (/dev/disk/by-uuid/abcd)
- reboot

```
adduser -g "User Name" user
adduser user wheel
apk add doas
echo "permit :wheel" > /etc/doas.d/doas.conf
```

```
apk add docker 
addgroup user docker
```

```
apk add qemu-img qemu-system-x86_64 libvirt-qemu
rc-update add libvirtd
addgroup user liibvirt
```

```
apk add mergerfs@edge-testing snapraid@edge-testing 
```

```
echo "MOTD" > /etc/motd
```
