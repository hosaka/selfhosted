# From live Alpine Linux

- Configure network interfaces with DHCP and restart them.
- Configure OpenSSH to get a remote shell.

```
setup-interfaces -a -r
setup-apkrepos -1
apk add python3
setup-sshd -k "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIqQwgcXplAfUV/YeJC8FIpZgl0Hr86P35mj6qcnpEJC alex@picknote.co" openssh
```

# From Ansible

```
echo "MOTD" > /etc/motd
```