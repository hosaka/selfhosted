# Purpose

With an existing NAS running docker compose I need a way to migrate all the services to the Incus cluster I have set up. This brings a few challenges.

## Services Migration

- [x] Services currently running have their data in docker volumes which are backed up with restic. These volumes need to migrate as-is to their respective Incus storage on the cluster.
- [x] Figure out a way for migrating services with a simple "disable on NAS, enable on Incus" process, after the service data is copied onto the cluster.
- [ ] Services that utilize HDD storage can not be immediately migrated and require some downtime, this involves backing up an existing ZFS pool onto a separate drive that is big enough to hold everything.

## NAS Migration

There are currently 5x HDDs and 2x SSDs in the NAS. The HDDs are in a ZFS raidz1 and SDDs are in BTRFS raid1. The procedure of migrating the NAS OS and the ZFS pool it carries is roughly:

1. Bring an additional HDD big enough to backup all the current data.
2. Create a ZFS snapshot and `zfs send | zfs recv` it to a backup drive.
3. Wipe Alpine Linux, replace it with an IncusOS and join the cluster.
4. Create an encrypted *ZFS pool* via IncusOS APIs with a single *ZFS volume*, so `hdd/incus`.
5. Create Incus *storage pool* on the new volume and one *storage volume* per old ZFS volume.
6. Migrate **old** ZFS volumes from a backup drive onto the new Incus *storage volumes*.

### Step by Step

#### Preparing Data Snapshot

Stop the stack.

Get the services container data: any `/data` that is on the SSDs and `pg_dump -Fc` for postgres volumes in docker compose, copy them off the NAS.

Prepare the backup HDD, plugged into the NAS (double check the by-id/backup-disk):
```bash
wipefs -a /dev/disk/by-id/backup-disk
zpool create \
  -o ashift=12 \
  -o compatibility=openzfs-2.2-linux \
  -O compression=lz4 \
  -O mountpoint=none \
  temp /dev/disk/by-id/backup-disk
```

Generate a ZFS snapshot of the pool and send it to the backup HDD:
```bash
zfs snapshot -r pool/root@migrate
zfs send -R pool/root@migrate | pv | zfs recv -u temp/backup
# wait for it to finish clean and export
zpool scrub temp
zpool export temp
```

#### Migrating to Incus

Prepare an IncusOS image for the joining NAS using `flasher-tool` directly or the `just image nas` recipe and flash it. Boot the OS, wait for it to install/reboot and a new remote with the correct IP address:
```bash
incus remote add nas <nas-lan-ip>
```

Before the `nas` can join the cluster, linstor needs to be configured:
```bash
incus remote switch nas
# set .config.enabled = true
incus admin os service edit linstor
incus config set storage.linstor.controller_connection http://<linstor-controller-ip>:3370
# pre-register the satellite on the linstor-controller
incus exec --project=internal linstor-controller -- linstor node create nas <nas-lan-ip> --node-type satellite
incus exec --project=internal linstor-controller -- linstor node list # nas should be Online
```

Join the cluster:
```bash
incus cluster join cluster: nas:
incus remote switch cluster
incus remote remove nas
# during the prompts
# member name: nas
# linstor pool source: <Enter>
# meshbr0 tunnel.mesh.interface: uplink
# lan parent: uplink
```

Wipe all the HDDs apart from the backup one. Double, triple check device ids!
```bash
incus admin os system storage wipe-drive -d '{"id":"/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1"}' --target nas
# repeat for each drive
```

Create a ZFS pool on the `nas` node:
```bash
incus admin os system storage edit --target nas
```

We need a raidz1 type here which allows one out of five failure for the HDDs. The result should look similar to:
```yaml
config:
  pools:
    - name: hdd
      type: zfs-raidz1
      devices:
        - /dev/disk/by-id/all-five-hdds-to-be-used
```

Create a new ZFS volume called `incus` on the new `hdd` pool:
```bash
incus admin os system storage create-volume -d '{"pool":"hdd","name":"incus","use":"incus"}' --target nas
```

Create a new ZFS volume called `hdd` on the existing `local` pool on each node in the cluster:
```bash
incus admin os system storage create-volume -d '{"pool":"local","name":"hdd","use":"incus"}' --target node-n
```

Create an new `hdd` Incus storage pool. Notice that the `source` property is different for the NAS node:
```bash
incus storage create hdd zfs source=local/hdd --target node-1
incus storage create hdd zfs source=local/hdd --target node-2
incus storage create hdd zfs source=local/hdd --target node-3
incus storage create hdd zfs source=hdd/incus --target nas
incus storage create hdd zfs
```

Create a storage volume for each of the volume that is present on the backed up ZFS pool:
```bash
incus storage volume create hdd media --target nas security.shifted=true
incus storage volume create hdd immich --target nas
incus storage volume create hdd voidrepo --target nas
# etc.
```

Create a helper VM that will facilitate the data migration:
```bash
incus init images:ubuntu/24.04 helper --vm --target nas
incus config device add helper temp disk source=/dev/disk/by-id/backup-disk-id
incus config device add helper media disk pool=hdd source=media path=/mnt/media
# ...same for immich, voidrepo
incus start helper
incus shell helper
apt update
apt install -y zfsutils-linux rsync
zpool import -o readonly=on temp && zfs mount -a
rsync -aHAX --numeric-ids --info=progress2 /mnt/pool/immich/ /mnt/immich/
# repeat for every volume that is being migrated
```

Restore the services and their `/data` as well as databases before enabling them one by one with `tofu apply`.

Disable wildcard domains in frpc.toml.tpl so all services are forwarded to the cluster.
