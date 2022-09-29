# From live Alpine Linux

- Configure network interfaces with DHCP and restart them.
- Configure OpenSSH to get a remote shell.

```
setup-interfaces -a -r
setup-apkrepos -1
apk add python3
setup-sshd -k "" openssh
```

# From Ansible

```
echo "MOTD" > /etc/motd
```
