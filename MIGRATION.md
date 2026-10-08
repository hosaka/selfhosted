# Purpose

With an existing NAS running docker compose I need a way to migrate all the services to the Incus cluster I have set up. This brings a few challenges.

## Services Migration

- [x] Services currently running have their data in docker volumes which are backed up with restic. These volumes need to migrate as-is to their respective Incus storage on the cluster.
- [x] Figure out a way for migrating services with a simple "disable on NAS, enable on Incus" process, after the service data is copied onto the cluster.
- [ ] Services that utilize HDD storage can not be immediately migrated and require some downtime, this involves backing up an existing ZFS pool onto a separate drive that is big enough to hold everything.

Order per service: **write the module → apply (without ingress) → stop the app → copy cert → restore data → start → add ingress → stop on NAS.**

### 0. Module prep
- Set `initial.uid`/`initial.gid` to the image's user: postgres alpine `70`, valkey `999:1000`, hotio and most others `1000`
- Postgres 18: mount the volume at `/var/lib/postgresql`, not `.../data`.
- Set an explicit `size` on `linstor` volumes if they need to exceed 10GiB (which is a default).
- Don't add the module's `ingress` to the services list yet.

### 1. Apply, then stop the app
```bash
tofu apply -var-file=env-prod.tfvars
incus stop <app>              # leave <app>-database running
```

### 2. Caddy certs
Copy only `certificates/<domain>`, not `acme/`. The cluster Caddy has its own accounts.
```bash
# NAS
doas tar czf /tmp/certs.tar.gz \
  -C /var/lib/docker/volumes/box_caddy-config/_data/caddy/certificates \
  acme-v02.api.letsencrypt.org-directory/<domain>
gzip -t /tmp/certs.tar.gz

# workstation
scp nas:/tmp/certs.tar.gz /tmp/ && gzip -t /tmp/certs.tar.gz
mkdir -p /tmp/certs && tar xzf /tmp/certs.tar.gz -C /tmp/certs
incus file push -r /tmp/certs/acme-v02.api.letsencrypt.org-directory/<domain> caddy/config/caddy/certificates/acme-v02.api.letsencrypt.org-directory/
incus exec caddy -- chown -R 1000:1000 /config/caddy/certificates
```

If the cluster Caddy has already issued its own cert for the domain (e.g. a ZeroSSL dir), delete that directory.

### 3a. Postgres
```bash
# NAS
docker compose stop <app>
docker compose exec -T <app>-database pg_dump -U <user> -Fc <db> > /tmp/<app>.dump

# cluster
incus file push /tmp/<app>.dump <app>-database/tmp/dump
incus exec <app>-database -- pg_restore -U <user> -d <db> --clean --if-exists --no-owner /tmp/dump
```

`--clean --if-exists` replaces the schema the app created on its first boot. A
custom-format dump from 14 restores into 18 without issues.

### 3b. Data volumes (via a helper container, never `file push` to a stopped instance)
`incus file push` into a stopped instance lands in its rootfs, not the volume: custom volumes aren't mounted while the instance is stopped.

```bash
# NAS
docker compose stop <app>
docker run --rm -v <project>_<app>-data:/data -v /tmp:/backup alpine \
  tar czf /backup/<app>.tar.gz -C /data .

# cluster
incus launch images:alpine helper --target <node>
incus config device add helper vol disk pool=linstor source=<app>-data path=/mnt
incus file push /tmp/<app>.tar.gz helper/tmp/
incus exec helper -- sh -c 'rm -rf /mnt/* && tar xzf /tmp/<app>.tar.gz -C /mnt'
incus delete -f helper
```

### 4. Start, verify, add ingress
```bash
incus start <app>
```

Check the instance logs. Then add `module.<app>.ingress` to the services list and apply. Caddy reloads, and frpc registers the exact domain, which takes precedence over the NAS wildcard, so traffic switches over. Remove the service from the NAS compose afterwards.

## NAS Migration

There are currently 5x HDDs and 2x SSDs in the NAS. The HDDs are in a ZFS raidz1 and SDDs are in BTRFS raid1. The procedure of migrating the NAS OS and the ZFS pool it carries is roughly:

1. Bring an additional HDD big enough to backup all the current data.
2. Create a ZFS snapshot and `zfs send | zfs recv` it to a backup drive.
3. Wipe Alpine Linux, replace it with an IncusOS and join the cluster.
4. Create an encrypted *ZFS pool* via IncusOS APIs with a single *ZFS volume*.
5. Create Incus *storage pool* on the new volume and one *storage volume* per old ZFS volume.
6. Migrate **old** ZFS volumes from a backup drive onto the new Incus *storage volumes*.

### Preparing Data Snapshot

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

### Migrating to Incus

Prepare an IncusOS image for the joining NAS using `flasher-tool` directly or the `just image node-4` recipe and flash it. Boot the OS, wait for it to install/reboot and a new remote with the correct IP address:
```bash
incus remote add node-4 <nas-lan-ip>
```

Before the `node-4` can join the cluster, linstor needs to be configured:
```bash
incus remote switch node-4
# set .config.enabled = true
incus admin os service edit linstor
incus config set storage.linstor.controller_connection http://<linstor-controller-ip>:3370
# pre-register the satellite on the linstor-controller
incus exec --project=internal cluster:linstor-controller -- linstor node create node-4 <nas-lan-ip> --node-type satellite
incus exec --project=internal cluster:linstor-controller -- linstor node list # node-4 should be Online
```

Join the cluster:
```bash
incus cluster join cluster: node-4:
incus remote switch cluster
incus remote remove node-4
# during the prompts
# member name: node-4
# linstor pool source: <Enter>
# meshbr0 tunnel.mesh.interface: uplink
# lan parent: uplink
```

Wipe all the HDDs apart from the backup one. Double, triple check device ids!
```bash
incus admin os system storage wipe-drive -d '{"id":"/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1"}' --target node-4
# repeat for each drive
```

Create a ZFS pool on the `node-4` node:
```bash
incus admin os system storage edit --target node-4
```

We need a raidz1 type here which allows one out of five failure for the HDDs. The result should look similar to:
```yaml
config:
  pools:
    - name: nas
      type: zfs-raidz1
      devices:
        - /dev/disk/by-id/all-five-hdds-to-be-used
```

Save the recovery key and configure scrub:
```bash
incus admin os system security show --target node-4
# add scrub_schedule: "0 0 * * 6" to the pool config
```

Create a new ZFS volume called `incus` on the new `nas` pool:
```bash
incus admin os system storage create-volume -d '{"pool":"nas","name":"incus","use":"incus"}' --target node-4
```

Create a new ZFS volume called `nas` on the existing `local` pool on each node in the cluster, apart from node-4:
```bash
incus admin os system storage create-volume -d '{"pool":"local","name":"nas","use":"incus","quota_in_bytes":67108864}' --target <node-1~3>
```

Add `node-4` to the cluster members in tofu, then create the `nas` Incus storage pool and its volumes:

```bash
tofu plan
tofu apply -target=null_resource.post_storage_volumes
incus storage volume list nas
```

Create a helper VM that will facilitate the data migration:
```bash
incus init images:ubuntu/24.04 helper --vm --target node-4

# for every volume that is being migrated (media, immich etc.,)
incus config device add helper temp disk source=/dev/disk/by-id/backup-disk-id
incus config device add helper media disk pool=nas source=media path=/mnt/media

incus start helper
incus shell helper
apt update
apt install -y zfsutils-linux rsync
zpool import -o readonly=on temp && zfs mount -a
# for every volume that is being migrated
findmnt /mnt/immich
rsync -aHAX --numeric-ids --info=progress2 /mnt/pool/immich/ /mnt/immich/
```

Restore the services and their `/data` as well as databases before enabling them one by one with `tofu apply`.

Disable wildcard domains in frpc.toml.tpl so all services are forwarded to the cluster.
