# Selfhosted

My selfhosted config.

## Hardware

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

Containers are run with docker, Cloudflare tunnel is the entrypoint with Caddy acting as a reverse proxy to other services. See `compose.yml` and the list of includes it contains.

I have previously attempted to run containers using rootless podman with moderate success, but inter-container networking was difficult and at times too slow (slurp4netns). The fact that other tools like kustomize are needed to have a flexible configuration was another downside. Perhaps I will revisit podman again someday.

### Configuration

All applications are configured with a single [default.env](default.env). This env file is encrypted using [SOPS](https://getsops.io/docs/) and must be decrypted first before it can be used: `sops decrypt default.env > .env`.

Individual services can be disabled by commenting them out from the include list in `compose.yml`.

## Backups

Backups are done using `restic` and `resticprofile`. See the [restic/README.md](restic/README.md) for details.

## Power

- 1 WD Red 5400 RPM 8TB drive consumes about 6W of power.
- At standby with all drives powered ON the consumption is 77W (default BIOS)
- At standby with all drives powered OFF the consumption is 45W (default BIOS)

## Todo

### Software

- [ ] Move cloudflared tunnel config to a local file in this repo
- [x] Browser sync, e.g. [syncstorage-rs](https://github.com/mozilla-services/syncstorage-rs) for Firefox
- [ ] CardDAV and CalDAV for calendar and contacts sync like [radicale](https://radicale.org/v3.html) or use [cal.com](https://github.com/calcom/cal.com)
- [ ] [Safe{Wallet}](https://github.com/safe-global/safe-wallet-web) for multisig wallets
- [ ] Code Statistics using [wakapi](https://wakapi.dev/) 

### Hardware

- [x] Replace the NIC with a TPU such as Coral PCIe Accelerator or a dGPU with a small form factor
