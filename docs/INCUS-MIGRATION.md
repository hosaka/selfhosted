# Purpose

With an existing NAS running docker compose I need a way to migrate all the services to the Incus cluster I have set up. This brings a few challenges.

- [x] Services currently running have their data in docker volumes which are backed up with restic. These volumes need to migrate as-is to their respective Incus storage on the cluster.
- [x] Figure out a way for migrating services with a simple "disable on NAS, enable on Incus" process, after the service data is copied onto the cluster.
- [x] Services that utilize HDD storage can not be immediately migrated and require some downtime, this involves backing up an existing ZFS pool onto a separate drive that is big enough to hold everything.

# NAS Migration - DONE

The NAS has 5x HDDs in a ZFS raidz1 (`pool`) and 2x SSDs in a BTRFS raid1 holding Alpine Linux and the docker volumes. Services that depend on HDDs move together with the NAS itself: the NAS gets wiped, reinstalled with IncusOS, joins the cluster as `node-4`, and the HDD data is restored from a backup drive.

Overview:

1. Back up the service data
2. Back up the ZFS pool
3. Prepare `node-4`
4. Install IncusOS
5. Join the cluster
6. Create the `nas` ZFS pool
    - 6a. Optional: Add the NVMe to LINSTOR
7. Create the `nas` storage pool and volumes
8. Copy the HDD data
9. Restore the services
10. Clean up

## 1. Back up the service data - DONE

The docker volumes and the immich database live on the SSDs, which get wiped when IncusOS is installed. Back them up and copy them off the NAS first.

What gets backed up, and the Incus volume each archive is restored into in step 9:

| NAS volume | Archive / Incus volume | Module |
|---|---|---|
| `box_immich-database-data` | `immich-db` (into `data/`) | `immich` |
| `box_jellyfin-config` | `jellyfin-data` | `jellyfin` |
| `box_kavita-config` | `kavita-data` | `kavita` |
| `box_navidrome-data` | `navidrome-data` | `navidrome` |
| `box_qbit-config` | `qbittorrent-data` | `qbittorrent` |
| `box_sabnzbd-config` | `sabnzbd-data` | `sabnzbd` |
| `box_lidarr-config` | `lidarr-data` | `servarr` |
| `box_prowlarr-config` | `prowlarr-data` | `servarr` |
| `box_radarr-config` | `radarr-data` | `servarr` |
| `box_sonarr-config` | `sonarr-data` | `servarr` |
| `box_jellyseerr-config` | `seerr-data` | `servarr` |
| `box_recyclarr-config` | `recyclarr-data` | `servarr` |
| `box_slskd-data` | `slskd-data` | `slskd` |
| `box_home-assistant-config` | `homeassistant-data` | `homeassistant` |
| `box_mosquitto-data` | `mosquitto-data` | `homeassistant` |

Create a directory for the archives on the ZFS pool. The NAS doesn't have the RAM to hold several GB of archives in a tmpfs `/tmp`, and as part of `pool/root` they also end up in the step 2 snapshot, as a second copy on the backup HDD:
```bash
# NAS
doas install -d -o user -g user /mnt/pool/migration
```

Stop the apps, but leave `immich-database` running for the dump:
```bash
# NAS
docker compose stop immich immich-machine-learning jellyfin kavita navidrome qbit qbitmanage sabnzbd lidarr prowlarr radarr sonarr jellyseerr recyclarr slskd voidrepo
```

Dump the immich database as a fallback. The primary restore copies its data directory (see 9.3), the dump follows Immich's own backup procedure in case that fails:
```bash
# NAS
docker compose exec -T immich-database pg_dump --clean --if-exists --dbname=immich --username=postgres | gzip > /mnt/pool/migration/immich-dump.sql.gz
```

Stop the database, its data directory is archived below and has to be in a clean, stopped state:
```bash
# NAS
docker compose stop immich-database
```

Archive the volumes:
```bash
# NAS
for pair in \
  box_immich-database-data:immich-db \
  box_jellyfin-config:jellyfin-data \
  box_kavita-config:kavita-data \
  box_navidrome-data:navidrome-data \
  box_qbit-config:qbittorrent-data \
  box_sabnzbd-config:sabnzbd-data \
  box_lidarr-config:lidarr-data \
  box_prowlarr-config:prowlarr-data \
  box_radarr-config:radarr-data \
  box_sonarr-config:sonarr-data \
  box_jellyseerr-config:seerr-data \
  box_recyclarr-config:recyclarr-data \
  box_slskd-data:slskd-data \
  box_home-assistant-config:homeassistant-data \
  box_mosquitto-data:mosquitto-data
do
  docker run --rm -v "${pair%%:*}":/data -v /mnt/pool/migration:/backup alpine \
    tar czf "/backup/${pair#*:}.tar.gz" -C /data .
done
```

Archive the Caddy certificates of the remaining domains:
```bash
# NAS
doas tar czf /mnt/pool/migration/certs.tar.gz \
  -C /var/lib/docker/volumes/box_caddy-config/_data/caddy/certificates \
  acme-v02.api.letsencrypt.org-directory/immich.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/immich.domain.tld \
  acme-v02.api.letsencrypt.org-directory/jellyfin.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/kavita.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/navidrome.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/navidrome.domain.tld \
  acme-v02.api.letsencrypt.org-directory/qbit.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/nzb.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/lidarr.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/prowlarr.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/radarr.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/seerr.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/sonarr.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/slskd.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/mirror.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/mirror.domain.tld \
  acme-v02.api.letsencrypt.org-directory/search.box.domain.tld \
  acme-v02.api.letsencrypt.org-directory/search.domain.tld \
  acme-v02.api.letsencrypt.org-directory/hass.box.domain.tld
```

Copy everything to the workstation:
```bash
# workstation
mkdir -p ~/nas-migration
scp '<nas-host>:/mnt/pool/migration/*.gz' ~/nas-migration/
```

Verify the archives arrived intact:
```fish
# workstation
for f in ~/nas-migration/*.gz
    gzip -t $f && echo "ok: $f"
end
```

## 2. Back up the ZFS pool - DONE

Stop the whole stack so nothing writes to the pool:
```bash
# NAS
docker compose stop
```

Save the dataset layout. It's needed later to find each dataset on the backup drive:
```bash
# NAS
doas zfs list -o name,mountpoint,canmount,used -r pool/root > /tmp/zfs-layout.txt

# workstation
scp <nas-host>:/tmp/zfs-layout.txt ~/nas-migration/
```

Power off the NAS, plug in the backup HDD and find its id. Double check it, the next command wipes it:
```bash
# NAS
ls -l /dev/disk/by-id/
```

Create the `temp` pool on the backup HDD. `compatibility=openzfs-2.2-linux` keeps it importable by the Ubuntu 24.04 helper VM later, which ships the same ZFS 2.2.2 as the NAS:
```bash
# NAS
wipefs -a /dev/disk/by-id/<backup-hdd-id>
zpool create \
  -o ashift=12 \
  -O compression=lz4 \
  -O mountpoint=none \
  temp /dev/disk/by-id/<backup-hdd-id>
```

Snapshot the pool and send it to the backup HDD. `-L` keeps the 1M records of `voidrepo` intact instead of splitting them into 128K blocks:
```bash
# NAS
zfs snapshot -r pool/root@migrate
zfs send -L -R pool/root@migrate | pv | zfs recv -u temp/backup
```

Scrub the backup, wait for the scrub to finish and check that it reports no errors before exporting:
```bash
# NAS
zpool scrub temp
zpool wait -t scrub temp
zpool status temp
zpool export temp
```

Shut down the NAS and disconnect the backup HDD. It stays disconnected until step 8, so the IncusOS installer can't touch it.

## 3. Prepare `node-4` - DONE

The IncusOS seed for the NAS is in `incus/node-4/`. It names the single NIC `uplink` like on the other nodes, the cluster networks rely on that name.

Review the `target` in `incus/node-4/install.yml` before building the image. It has to match the drive IncusOS should be installed to, as the installer wipes it.

Prepare tofu for `node-4`. The services restored in step 9 target it, so `var.cluster` needs a `node-4` entry:

- `variables.tf`: uncomment `node-4` in `var.cluster`. Add `var.cluster.node-4.target` to both validations (the non-empty list and the distinct targets) and change `== 3` to `== 4`.
- `environment.auto.tfvars`: add `node-4 = {}`.

Check the changes. There should be no changes in the plan, as `node-4` isn't a cluster member yet:
```bash
just lint
tofu plan
```

Build the image and flash it to a USB drive:
```bash
just image node-4
just flash incus-os-node-4.img /dev/disk/by-id/<usb-drive-id>
```

## 4. Install IncusOS - DONE

Make sure the backup HDD is disconnected. Boot the NAS from the USB drive and wait for IncusOS to install and reboot.

Add the NAS as a remote:
```bash
incus remote add node-4 <nas-lan-ip>:8443
```

## 5. Join the cluster - DONE

LINSTOR has to be configured on `node-4` before it can join.

Switch to the `node-4` remote and enable the LINSTOR service. Set `.config.enabled` to `true` in the editor:
```bash
incus remote switch node-4
incus admin os service edit linstor
```

Point `node-4` at the LINSTOR controller:
```bash
incus config set storage.linstor.controller_connection http://<linstor-controller-ip>:3370
```

Pre-register `node-4` as a satellite on the controller and check that it shows up as `Online`:
```bash
incus exec --project=internal cluster:linstor-controller -- linstor node create node-4 <nas-lan-ip> --node-type satellite
incus exec --project=internal cluster:linstor-controller -- linstor node list
```

The join asks for every member-specific key set on the existing storage pools and networks, as `"<key>" property for storage pool "<pool>"` or `... for network "<network>"`. Check what the existing members have, `node-4` gets the same values:
```bash
incus storage show cluster:local --target node-1
incus storage show cluster:linstor --target node-1
incus network show cluster:meshbr0 --target node-1
incus network show cluster:lan --target node-1
```

Join the cluster:
```bash
incus cluster join cluster: node-4:
```

Answer the prompts:
```
What IP address or DNS name should be used to reach this server? [default=10.10.0.104]:
What member name should be used to identify this server in the cluster? [default=node-4.<hostname>]: node-4
All existing data is lost when joining a cluster, continue? (yes/no) [default=no] yes
Choose "parent" property for network "lan": uplink
Choose "tunnel.mesh.interface" property for network "meshbr0": uplink
Choose "source" property for storage pool "linstor": linstor
Choose "source" property for storage pool "local": local/incus
Choose "zfs.pool_name" property for storage pool "local": local/incus
```

If it asks for anything else, answer with what `node-1` has from the check above.

Switch back to the cluster remote and remove the temporary one:
```bash
incus remote switch cluster
incus remote remove node-4
```

## 6. Create the `nas` ZFS pool - DONE

List the drives on `node-4` and check the ids of the five HDDs. IncusOS may report them differently (e.g. as `wwn-*`), so use whatever it lists:
```bash
incus admin os system storage show --target node-4
```

Wipe the HDDs. Double, triple check the device ids!
```fish
incus init images:ubuntu/24.04 helper --vm --target node-4
for s in VAKD8J6L VAKEE7RL VDGBKXND VDGLA6GD VDJ0YV7K
    incus config device add helper hdd-$s disk source=/dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_$s
end

incus start helper
incus shell helper
```

Clear the labels inside the VM. The disks show up with the device name in their by-id, so check the mapping first:
```bash
apt update && apt install -y zfsutils-linux gdisk
lsblk -o NAME,SIZE,FSTYPE,LABEL
```

The old pool used whole disks, so ZFS created partitions, and its labels sit on partition 1, not on the raw disk. Clear those first, then the remaining signatures and the partition table:
```bash
for d in $(ls /dev/disk/by-id/ | grep 'hdd-' | grep -v part); do
  dev=/dev/disk/by-id/$d
  zpool labelclear -f ${dev}-part1 2>/dev/null
  wipefs -a ${dev}-part* $dev
  sgdisk -Z $dev
done
lsblk -o NAME,SIZE,FSTYPE      # no partitions, no zfs_member left on the five disks
```

Detach the drives and keep the helper for step 8.
```fish
incus stop helper
for s in VAKD8J6L VAKEE7RL VDGBKXND VDGLA6GD VDJ0YV7K
    incus config device remove helper hdd-$s
end
```

Create the pool:
```bash
incus admin os system storage edit --target node-4
```

Add a `zfs-raidz2` pool, which survives two of the five HDDs failing:
```yaml
config:
  pools:
    - name: nas
      type: zfs-raidz1
      devices:
        - /dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_VAKD8J6L
        - /dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_VAKEE7RL
        - /dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_VDGBKXND
        - /dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_VDGLA6GD
        - /dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_VDJ0YV7K
```

The pool is encrypted. Save the recovery key somewhere safe:
```bash
incus admin os system security show --target node-4 > incus/node-4/recovery.key
incus admin os system security retrieved
```

Create the `incus` volume on the new pool:
```bash
incus admin os system storage create-volume -d '{"pool":"nas","name":"incus","use":"incus"}' --target node-4
```

The `nas` Incus storage pool has to exist on every cluster member. Give the other nodes a small `nas` volume on their `local` pool:
```bash
incus admin os system storage create-volume -d '{"pool":"local","name":"nas","use":"incus","quota_in_bytes":67108864}' --target node-1
incus admin os system storage create-volume -d '{"pool":"local","name":"nas","use":"incus","quota_in_bytes":67108864}' --target node-2
incus admin os system storage create-volume -d '{"pool":"local","name":"nas","use":"incus","quota_in_bytes":67108864}' --target node-3
```

## 6a. Optional: Add the NVMe to LINSTOR

The NAS's NVMe can become `node-4`'s LINSTOR storage, like the NVMes on the other nodes. Without it, `node-4` is a diskless LINSTOR satellite and reaches every replicated volume over the network.

This mirrors what `just bootstrap-linstor` did for `node-1~3`, and can also be done any time later.

Wipe the NVMe:
```bash
incus admin os system storage wipe-drive -d '{"id":"/dev/disk/by-id/nvme-WDC_WDS100T2B0C-00PXH0_210246476212"}' --target node-4
```

Add the `nvme` pool next to the `nas` pool:
```bash
incus admin os system storage edit --target node-4
```

```yaml
config:
  pools:
    - name: nas
      ...
    - name: nvme
      type: zfs-raid0
      devices:
        - /dev/disk/by-id/nvme-WDC_WDS100T2B0C-00PXH0_210246476212
```

Create the `linstor` volume on it:
```bash
incus admin os system storage create-volume -d '{"pool":"nvme","name":"linstor","use":"linstor"}' --target node-4
```

Register it as a LINSTOR storage pool and check that `node-4` shows up:
```bash
incus exec --project=internal linstor-controller -- linstor storage-pool create zfsthin node-4 nvme nvme/linstor
incus exec --project=internal linstor-controller -- linstor storage-pool list
```

Existing volumes keep their replicas where they are, LINSTOR doesn't rebalance.

## 7. Create the `nas` storage pool and volumes - DONE

Enable the pool and its volumes in tofu:

- `storage_pools.tf`: uncomment the `nas_sources` locals, `incus_storage_pool.nas_per_node`, `incus_storage_pool.nas` and the `incus_storage_pool.nas` entry in `post_storage_pools`.
- `storage_volumes.tf`: uncomment the `media`, `immich`, `voidrepo` and `private` volumes and their entries in `post_storage_volumes`.

Review the plan:
```bash
tofu plan
```

It should only add resources:

- the `["node-4"]` instances of everything with `for_each = local.members`: the `backups`, `images` and `logs` volumes, `incus_server.this_per_node`, and the per-member resources in `metrics`
- the `nas` pool: a `nas_per_node` for each of the four members and the cluster-wide `nas`
- the `media`, `immich`, `voidrepo` and `private` volumes

Nothing should change or be destroyed on `node-1`, `node-2` or `node-3`.

There should be no `incusbr0`, `meshbr0`, `lan`, `local` or `linstor` per-node resources for `node-4`, and no satellite registration in the `linstor` module. Those only cover `local.founding_members` (`node-1~3`): per-member config can only be defined before a pool or network exists, so `node-4` got it from the join prompts in step 5 instead. The provider can't import clustered pools either, so if the plan does want to create them, stop and check `local.founding_members` before applying.

Create the storage pool and volumes, and check that the volumes exist:
```bash
tofu apply -target=null_resource.post_storage_volumes
incus storage volume list nas
```

The target above already creates `node-4`'s `backups`, `images` and `logs` volumes, but not the server config that points `node-4` at them (`incus_server.this_per_node`), or the `metrics` module's per-member server config and scrape targets. Apply those too:
```bash
just bootstrap
just apply metrics
```

## 8. Copy the HDD data - DONE

Connect the backup HDD to the NAS and find its id on `node-4`. It should be listed without a `member_pool`:
```bash
incus admin os system storage show --target node-4
```

Create a helper VM on `node-4`:
```bash
incus init images:ubuntu/24.04 helper --vm --target node-4
```

Attach the backup HDD as a raw disk:
```bash
incus config device add helper temp disk source=/dev/disk/by-id/<backup-hdd-id>
```

Attach the target volumes:
```fish
for v in immich media private voidrepo
  incus config device add helper $v disk pool=nas source=$v path=/mnt/$v
end
```

Start the helper and open a shell:
```bash
incus start helper
incus shell helper
```

Install the tools:
```bash
# helper
apt update
apt install -y zfsutils-linux rsync
```

Import the backup pool read-only, under the `/backup` altroot. `send -R` carried the NAS mountpoints over (`pool/root` had `mountpoint=/mnt/pool`), so without the altroot every dataset would mount at its old NAS path, on top of whatever is in the helper's `/mnt`. `-R` also sets `cachefile=none`, so the helper won't remember the pool:
```bash
# helper
zpool import -o readonly=on -R /backup temp
mkdir -p /etc/exports.d && zfs mount -a
```

Check where the datasets are mounted. Expect `/backup/mnt/pool/...`, and compare with `~/nas-migration/zfs-layout.txt`. Datasets with `canmount=noauto`/`off` or `mountpoint=legacy` don't mount automatically, mount those by hand with `mount -t zfs -o ro <dataset> <path>`:
```bash
# helper
zfs list -o name,mountpoint,mounted -r temp
```

Check that the target volumes are attached, and not just directories on the VM's root filesystem:
```bash
# helper
for v in immich media private voidrepo; do findmnt /mnt/$v; done
```

Copy the data. Use the source paths `zfs list` printed, the ones below assume the old NAS layout:
```bash
# helper
for pair in immich:immich private:private storage/media:media voidrepo:voidrepo; do
  src=${pair%%:*}; dst=${pair#*:}
  echo "== $src -> $dst"
  rsync -aH --numeric-ids --info=progress2 "/backup/mnt/pool/$src/" "/mnt/$dst/" || break
done
```

Export the backup pool and leave the helper:
```bash
# helper
zpool export temp
exit
```

Delete the helper:
```bash
incus delete -f helper
```

Disconnect the backup HDD. Keep it untouched until every service is restored and verified.

## 9. Restore the services - DONE

Repeat this step for every service, one at a time.

### 9.1 Prepare the module - DONE

- Set `initial.uid`/`initial.gid` on its volumes to the image's user: `70` for postgres alpine, `999` for Debian-based postgres, `999:1000` for valkey, `1000` for hotio and most others.
- If the service moves to Postgres 18, mount the database volume at `/var/lib/postgresql`, not `.../data`.
- Set an explicit `size` on `linstor` volumes that need more than the default 10G. None of the archived volumes do: the largest, `jellyfin-data`, is 1.9G.
- Comment out the app's `incus_instance`, so only its database and volumes get created.
- Uncomment the module in `main.tf`, but don't add its `ingress` to the services list yet.

### 9.2 Apply the database and volumes - DONE

```bash
just apply <app>
```

### 9.3 Restore the database - DONE

Only `immich` has a database. It keeps the exact same image (`14-vectorchord0.4.3-pgvectors0.2.0`), so its data directory is copied over as-is instead of restoring a dump.

The paths differ between the two: on the NAS the volume was mounted at `/var/lib/postgresql/data`, so the archive's root is `PGDATA`. On the cluster `immich-db` is mounted one level higher at `/var/lib/postgresql`, so `PGDATA` is the volume's `data/` directory. 9.2 already started the database once and `initdb` created a fresh, empty `data/`, which gets replaced.

Stop the database:
```bash
incus stop immich-database
```

Attach the volume to a helper container:
```bash
incus launch images:alpine helper --target <node>
incus config device add helper vol disk pool=linstor source=immich-db path=/mnt
incus file push ~/nas-migration/immich-db.tar.gz helper/tmp/
```

Replace the fresh data directory. Postgres requires `PGDATA` to be owned by its user (`999` in the Debian-based image) with mode `0700`:
```bash
incus exec helper -- rm -rf /mnt/data
incus exec helper -- mkdir -m 700 /mnt/data
incus exec helper -- chown 999:999 /mnt/data
incus exec helper -- tar xzf /tmp/immich-db.tar.gz -C /mnt/data
```

Check that the files are owned by `999` and that `PG_VERSION` says `14`:
```bash
incus exec helper -- ls -ln /mnt/data
incus exec helper -- cat /mnt/data/PG_VERSION
```

Remove the helper and start the database:
```bash
incus delete -f helper
incus start immich-database
just logs immich-database
```

#### Fallback: restore the dump

If the database doesn't come up from the copied data directory, restore the dump instead, following Immich's documented procedure. Start from an empty database: remove `data/` with the helper as above (without extracting anything), start `immich-database` so `initdb` recreates it, then:
```bash
incus file push ~/nas-migration/immich-dump.sql.gz immich-database/tmp/
incus exec immich-database -- sh -c "gunzip --stdout /tmp/immich-dump.sql.gz \
  | sed \"s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g\" \
  | psql --dbname=immich --username=postgres --single-transaction --set ON_ERROR_STOP=on"
```

The `sed` rewrites the empty `search_path` the dump sets, so the vector extension functions and indexes resolve during the restore.

### 9.4 Restore the data volume - DONE

Restore every archive that belongs to the module, see the table in step 1. The archives are named after their Incus volume. `immich-db` is the exception, it was already restored into its `data/` directory in 9.3.

Never `incus file push` into a stopped instance: custom volumes aren't mounted while it's stopped, so the files land in its rootfs instead of the volume. Use a helper container instead. The volume is still empty, as the app has never started.

```bash
incus launch images:alpine helper --target <node>
incus config device add helper vol disk pool=linstor source=<volume> path=/mnt
incus file push ~/nas-migration/<volume>.tar.gz helper/tmp/
incus exec helper -- tar xzf /tmp/<volume>.tar.gz -C /mnt
incus delete -f helper
```

### 9.5 Restore the Caddy certificate - DONE

Extract the certificates once:
```bash
mkdir -p ~/nas-migration/certs
tar xzf ~/nas-migration/certs.tar.gz -C ~/nas-migration/certs
```

Push the app's certificate to Caddy and fix the ownership:
```bash
incus file push -r ~/nas-migration/certs/acme-v02.api.letsencrypt.org-directory/<domain> caddy/config/caddy/certificates/acme-v02.api.letsencrypt.org-directory/
incus exec caddy -- chown -R 1000:1000 /config/caddy/certificates
```

If the cluster Caddy has already issued its own certificate for the domain (e.g. a ZeroSSL directory), delete that directory.

### 9.6 Start the apps

Start them one by one, so a failing app is easy to spot: uncomment one app's `incus_instance` and apply:
```bash
just apply <module>
```

Check its logs before uncommenting the next one:
```bash
just logs <instance>
```

Once all of the module's apps are running, uncomment `module.<module>.ingress` in the services list in `main.tf` and apply the ingress:
```bash
just apply ingress
```

## 10. Clean up

Check that tofu and the cluster agree:
```bash
tofu plan
```

### 9.7 Switch OpenWRT forwarding - DONE

The OpenWrt dnsmasq still resolves `*.box.domain.tld` to the NAS Caddy, so every `.box` domain breaks once the NAS is wiped. Point it at the cluster Caddy (`10.10.0.126`) instead. The services that are still on the NAS stay unreachable until they're restored in step 9.

Find the current entry:
```bash
# router
uci show dhcp | grep box.domain.tld
```

Replace it with the cluster Caddy and restart dnsmasq:
```bash
# router
uci del_list dhcp.@dnsmasq[0].address='/box.domain.tld/<nas-lan-ip>'
uci add_list dhcp.@dnsmasq[0].address='/box.domain.tld/10.10.0.126'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

### 10.1 Switch FRP back to plain TCP - DONE

Prepare both sides first. In `ingress/frpc.toml.tpl`, replace the `https-cluster` and `http-cluster` proxies with plain TCP ones:
```toml
[[proxies]]
name = "https"
type = "tcp"
localIP = "${caddy_ip}"
localPort = ${caddy_ports.https}
remotePort = ${caddy_ports.https}
transport.proxyProtocolVersion = "v2"

[[proxies]]
name = "http"
type = "tcp"
localIP = "${caddy_ip}"
localPort = ${caddy_ports.http}
remotePort = ${caddy_ports.http}
transport.proxyProtocolVersion = "v2"
```

The `customDomains` were the only user of `local.public_domains`, so remove that local and its `public_domains` argument to `templatefile` in `ingress/ingress.tf:L31`. Don't apply yet:
```bash
just lint
```

On the FRP server, edit `frps.toml`, but don't restart frps yet:

- remove `vhostHTTPSPort` and `vhostHTTPPort`
- if there's an `allowPorts` list, make sure it includes `80` and `443`

Switch both sides back to back. Restarting frps drops the vhost routing, frpc reconnects with the old config and its vhost proxies get rejected until `just apply ingress` reloads it:
```bash
# FRP
sudo systemctl restart frps
```

```bash
just apply ingress
```

Check that frpc registered the new proxies, the log should show `start proxy success` for `https` and `http`:
```bash
incus exec frpc -- tail -n 30 /tmp/frpc.log
```

Check public and SSH connections with `curl` and `ssh`.

### 10.2 Finish up

Once every service is verified, the backup HDD and `~/nas-migration` can be wiped.
