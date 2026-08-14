# Purpose

With an existing NAS running docker compose I need a way to migrate all the services to the Incus cluster I have set up. This brings a few challenges:

- Services currently running have their data in docker volumes which are backed up with restic. These volumes need to migrate as-is to their respective Incus storage on the cluster. This could be as simple as `rsync` or even `tar | scp`.
- Figure out a way for migrating services with a simple "disable on NAS, enable on Incus" process, after the service data is copied onto the cluster.
- Services that utilize HDD storage can not be immediately migrated and require some downtime, this involves backing up an existing ZFS pool onto a separate drive that is big enough to hold everything.

## Services Migration

## ZFS Migration

There are currently 5x HDDs and 2x SSDs in the NAS. The HDDs are in a ZFS raidz1 and SDDs are in BTRFS raid1. The procedure of migrating the NAS OS and the ZFS pool it carries is roughly:

1. Bring an additional HDD big enough to backup all the current data.
2. Create a ZFS snapshot and `zfs send | zfs recv` it to a backup drive.
3. Wipe Alpine Linux, replace it with an IncusOS and join the cluster.
4. Create an encrypted *ZFS pool* via IncusOS APIs with a single *ZFS volume*, so `hdd/incus`.
5. Create Incus *storage pool* on the new volume and one *storage volume* per old ZFS volume.
6. Migrate **old** ZFS volumes from a backup drive onto the new Incus *storage volumes*.

### Step by Step

Wipe all the HDDs apart from the backup one. Double, triple check device ids!
```bash
incus admin os system storage wipe-drive -d '{"id":"/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1"}' --target nas
# repeat for each drive
```

Create a ZFS pool on the joined `nas` node:
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
incus storage create hdd zf
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
incus config device add helper temp disk source=/dev/disk/by-id/<backup-disk>
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

TODO: Verify that the media volume can be mounted by multiple container instances at the same time and repeat this exercise on a Proxmox simulated cluster with dummy data generated with something like:
```bash
dd if=/dev/urandom of=downloads/file1.bin bs=1M count=2048 status=progress
ln downloads/file1.bin collection/file1.bin
```
