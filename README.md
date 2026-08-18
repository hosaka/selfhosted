# Selfhosted

My selfhosted config.

## Hardware

**The Rack**

- KeepLiNK KP-9000-9XH-X 8x2.5 Gb and 1x10Gb Unmanaged Switch
- 3x Lenovo M920q Tiny PCs, each with 2x Kioxia XG6 256GB NVME, 2x SK Hynix DDR4 PC4-2666V 8GB and 2.5 GbE NIC
- ShrikeLab PDU V1 with 5x 65W USB-C outputs, based on Meanwell HRP-300-24 PSU
- 12U 10" DeskPi RackMate T2 Black Version

**The NAS**

- Ryzen 5 5600G 3.9GHz 6 core
- Gigabyte B550I Mini ITX
- XPG GAMMIX D45 DDR4-3200 2x16GB
- WD Blue SN550 NVME 1TB
- Kingston Q500 SSD 2x240GB
- WD Red 5400 RPM 5x8TB
- Silverstone SX650-G 650W SFX
- Intel I350-T4 4x1Gb NIC
- APC BK500JP UPS
- Dual Edge TPU M.2
- Dual Edge TPU PCIe Adapter
- Jonsbo N1 Mini ITX

## Software

### Orchestration

M920q PCs are clustered together using [IncusOS](https://linuxcontainers.org/incus-os/) responsible for OCI and VM instances that run individual services while the mITX machine takes on the NAS responsibilities. [OpenTofu](https://opentofu.org) is used for "Infra as Code" configuration.

> I have previously ran the services with docker compose but decided to switch to a virtualization platform due to running out of compute power on the NAS and having to deal with outages when the NAS had to either go down for maintenance or otherwise had a bad day and would bring my whole stack down. I initially reached for [Proxmox VE](https://www.proxmox.com) as a battle tested hypervisor but settled on [IncusOS](https://linuxcontainers.org/incus-os/) for its simplicity, immutability and being able to almost entirely set it up using IaC. For the last docker compose version see commit `5bed864b9d`.

> I have previously attempted to run containers using rootless podman with moderate success, but inter-container networking was difficult and at times too slow (slurp4netns). The fact that other tools like kustomize are needed to have a flexible configuration was another downside. Podman Quadlets have been available since but requires systemd. Perhaps I will revisit podman again someday. For the last podman version see commit `9dcddc6c6d`.

### Setup

Create an Incus cluster with all nodes. This also is detailed in the [IncusOS Docs](https://linuxcontainers.org/incus-os/docs/main/tutorials/incus-cluster/).
```bash
# pass the IP addresses for nodes 1..3
just cluster 10.10.0.101 10.10.0.102 10.10.0.103
```

Bootstrap the cluster configuration:
```bash
tofu init
just bootstrap
```

### Storage
Each node in the cluster has a spare NVME dedicated to distributed storage with [LINSTOR](https://linuxcontainers.org/incus/docs/main/reference/storage_linstor/). Deploying this with an IncusOS cluster is somewhat cumbersome and requires manual steps, but can be semi-automated with a just recipe:
```bash
just bootstrap-linstor
```

1. When prompted with the `linstor` service configuration, make sure that each node has `enabled` set to true. The result should look similar to this:
```yaml
config:
  enabled: true
```

2. When prompted with the storage configuration, define an ZFS pool on each node that will be used by Linstor (also see [Storage Docs](https://linuxcontainers.org/incus-os/docs/main/reference/system/storage/#managing-volumes
)). Add the new `nvme` pool under `config`. Double check that the disk ID is listed under `drives` and does not currently belong to an existing pool:
```yaml
config:
  pools:
    - name: nvme
      type: zfs-raid0
      devices:
      - /dev/disk/by-id/<disk-id-to-be-used-by-incus>
```

The rest of the recipe will deploy the Linstor controller, create storage pools that will contribute capacity to the cluster (this runs on the linstor-controller container), and finally create an Incus `linstor` pool that can be used by the rest of the services.

3. Check the IP address of the `linstor-controller` instance and add it to a list of static leases in the router:
```bash
incus info --project internal linstor-controller
```

### Network

A [frp server](https://github.com/fatedier/frp) on a VPS is the entrypoint with Caddy acting as a reverse proxy to other services. See the [ingress/](ingress/) configuration for more details.

> I have previously ran Cloudflare Tunnel but decided to ditch it in favour of having more control over non HTTP traffic and more control over my traffic in general. Using Fast Reverse Proxy makes TCP/UDP much easier to work with and in most cases doesn't require connecting client to install any additional software. For the last CF Tunnel version see commit `b904227fc6`.

### Configuration

All applications are configured with a single [secrets.default.tfvars](secrets.default.tfvars). This file is encrypted using [SOPS](https://getsops.io/docs/) with [age](https://age-encryption.org/) and must be decrypted first before it can be used:
```bash
just decrypt secrets
```

When changes were made to the secrets, they can be encrypted back for git storage:
```bash
just encrypt secrets
```

> Prior to commit `6adee98aed` SOPS with PGP backend was used.

## Backups

Backups are done using `restic` and `resticprofile`. See the [restic/README.md](restic/README.md) for details.

## Power

- 1 WD Red 5400 RPM 8TB drive consumes about 6W of power.
- At standby with all drives powered ON the consumption is 77W (default BIOS)
- At standby with all drives powered OFF the consumption is 45W (default BIOS)

## Todo

### Software

- [ ] Make just cluster and bootstrap-linstor recipes idempotent. Incus CLI does have a `--format=json` that can be piped to `jq` where we can check the current state
- [ ] Better automation for Linstor provisioning, perhaps getting [Operations Center](https://github.com/FuturFusion/operations-center) involved
- [ ] CardDAV and CalDAV for calendar and contacts sync like [radicale](https://radicale.org/v3.html)
- [ ] [Safe{Wallet}](https://github.com/safe-global/safe-wallet-web) for multisig wallets
- [x] Browser sync, e.g. [syncstorage-rs](https://github.com/mozilla-services/syncstorage-rs) for Firefox
- [x] Code Statistics using [wakapi](https://wakapi.dev/)

### Hardware

- [x] Replace the NIC with a TPU such as Coral PCIe Accelerator or a dGPU with a small form factor

## Mirrors
This repository is hosted on [Forgejo](https://code.hosaka.cc/hosaka/selfhosted) which mirrors to the following git forges:
- [<img src="https://raw.githubusercontent.com/humanetech-community/awesome-humane-tech/main/logo/codeberg.svg?sanitize=true" width="16"/>](https://codeberg.org/hosaka/selfhosted) - https://codeberg.org/hosaka/selfhosted
- [<img src="https://raw.githubusercontent.com/humanetech-community/awesome-humane-tech/main/logo/github.svg?sanitize=true" width="16"/>](https://github.com/hosaka/selfhosted) - https://github.com/hosaka/selfhosted

