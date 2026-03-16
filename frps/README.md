# Fast Reverse Proxy

## Quickstart
Install ansible, for example using mise:

```bash
mise install && mise run prep
```

Decrypt the secrets:
```bash
mise run decrypt
```

Adjust the `inventory.yml` if necessary and deploy the playbook:
```bash
mise run frps
```

## Inventory
This playbook can be deployed to any Debian machine with SSH access and Python installed.
