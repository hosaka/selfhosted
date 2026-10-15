# Backups

Backups happen in three layers:

- **Incus snapshots** of every volume with state, for undoing mistakes. They live on the same disks as the volume, so it's not really a backup.
- **Local restic repository** (`nas`) on the HDDs in `node-4`, for data that lives on LINSTOR.
- **Remote restic repository** (`s3`) in an S3 bucket, for everything that needs backing up.

[Backrest](https://github.com/garethgeorge/backrest) runs [restic](https://restic.net) for both repositories. Full tofu configuration is in the [backups/](../backups/) module.

## Snapshots

Every volume with state takes a daily snapshot named `daily-<date>`. The schedule is defined once as `local.daily_snapshot` in [storage_volumes.tf](../storage_volumes.tf) and passed to other application modules. Application volumes keep 7 days of snapshots.

The schedule runs in the cluster's local time, which comes from the network seed (see [incus/node-1/network.yml](../incus/node-1/network.yml)).

## Backrest

Backrest is configured by tofu from [backups/backrest.tf](../backups/backrest.tf), any change made in the UI are lost on the next apply.

The container talks to the Incus API with its own client certificate ([backups/backup.crt](../backups/backup.crt)). It needs it to snapshot, clone and attach volumes and to dump databases.

### Repositories

| Repository | Where | Prune | Check |
|---|---|---|---|
| `nas` | the `restic` volume on the `nas` pool, at `/repos/nas` | weekly, Sunday 03:00 | weekly, Sunday 03:30, structure only |
| `s3` | an S3 bucket | quarterly, on the 1st at 05:00 | monthly, on the 15th at 05:00, reads a random 5% of the data |

Both prune with `maxUnusedPercent` 10 and share one password. The password, the bucket's URI and its keys are in the `backups` block of the secrets.

### Plans

Each app that needs to be backed up has a `backups` output listing its applications, their volumes and Postgres instances. [main.tf](../main.tf) merges them into the module's `sources`, which gives every application two plans:

- `<app>-nas` at 02:00, keeping 7 daily, 4 weekly and 6 monthly snapshots
- `<app>-s3` at 04:00, keeping 7 daily, 4 weekly and 12 monthly snapshots

Volumes on the `nas` pool (for example Immich and OpenCloud) go to the `s3` repository only. They are listed in `nas_sources` in [main.tf](../main.tf) and backed up at 04:30, after the applications:

- `immich-library-s3`: all of Immich's `/data`
- `opencloud-files-s3`: personal files from OpenCloud

Backrest runs one task at a time, so the plans queue up and run one after another.

Every application plan excludes common patterns like `logs`, `log`, and `cache`, plus its own excludes from the module outputs.

### How a backup runs

Application plans run three hooks around restic:

1. `dump-databases` runs `pg_dumpall` in each of the application's Postgres instances and writes plain SQL because restic deduplicates well between runs.
2. `mount-clones` takes a `backup` snapshot of each volume, copies it into a `backup-<volume>` volume (it's a ZFS clone basically) and attaches the clone read-only.
3. restic backs up the clones and the dumps.
4. `unmount-clones` detaches and deletes the clones and the snapshots. It also runs when the backup fails, and `mount-clones` runs it first to clear anything a borked run might have left behind.

A failing `dump-databases` or `mount-clones` cancels the backup. The snapshot makes the copy consistent without having to stop the applications.

The `nas` pool's volumes (`immich`, `opencloud`) are attached read-only and backed up live, without hooks.

### Not backed up

- Most of the `media` because it can be re-obtained.
- The instances themselves, which tofu can rebuild.
- Caches like valkey, and other non-essentials like `prometheus-data`, `loki-data` and `diun-data`.

## Notifications

Both repositories have two Gotify hooks using the "Backrest" application, so they cover every plan's backups and forgets as well as the repository's prune and check. A message that fails to send is only logged by Backrest and doesn't fail the task.

## Monitoring

[restic-exporter](https://github.com/ngosang/restic-exporter) reads each repository directly (`restic-exporter-nas` and `restic-exporter-s3`, see [backups/restic-exporter.tf](../backups/restic-exporter.tf)) and refreshes hourly. The `nas` one has the `restic` volume attached read-only and all its restic commands use `--no-lock`, so it never gets in Backrest's way.

Prometheus scrapes both in the `restic` job, labelling every series with `repository` and `plan`. The Backups dashboard in Grafana shows detailed metrics about snapshots in each repository such as total sizes, file counts and a few pretty graphs.

## Restores

**From an Incus snapshot**

`incus storage volume snapshot restore` only restores a volume's latest snapshot, with its instances stopped.

**From the `nas` repository**

```bash
# volume and snapshot ID from the Backrest UI, or latest
just restore-volume gotify-data latest
```

This runs `restore-volume` in the `backrest` container. It checks that the snapshot contains the volume, asks you to type the volume name to confirm, stops the instances that use the volume, restores it in place and starts them again. Files that the plan excludes are neither restored nor deleted. If it fails half way, the volume stays attached and the instances stay stopped, running it again retries the restore.

It only stops what uses the volume. For an application with several volumes or a separate database instance (e.g. `immich`, `forgejo`, `paperless`), stop the application first.

**A database**

Stop the application, then load the dump from a snapshot into its Postgres instance:

```bash
incus exec backrest -- sh -c 'RESTIC_PASSWORD_FILE=/etc/backrest/restic.password restic -r /repos/nas dump latest --tag plan:authelia-nas /var/lib/backup/db/authelia-database.sql' \
  | incus exec authelia-database -- sh -c 'psql -U "$POSTGRES_USER" -d postgres'
```

The dump drops and recreates the databases and roles. Errors about dropping the role it runs as, or creating a role that already exists, are expected.

**From the `s3` repository**

`restore-volume` only uses the `nas` repository. The `s3` plans can be browsed and restored in the Backrest UI like the `nas` ones, or with restic in the `backrest` container using the S3 credentials from the secrets.

- TODO: more details on restoring from s3 buckets with an example
