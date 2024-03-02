# Restic backups

1. Install [restic](https://github.com/restic/restic) and [resticprofile](https://github.com/creativeprojects/resticprofile) on the host machine
2. Configure restic for [rootless backups](https://restic.readthedocs.io/en/stable/080_examples.html#backing-up-your-system-without-running-restic-as-root) using `setcap`
3. Link this folder to `/usr/local/etc/resticprofile`
4. Run resticprofile with `doas -u restic resticprofile` (alias it to something like rst)
5. resticprofile will automatically pickup the `profiles.yaml`
6. Use `resticprofile schedule --all` to add schedule all profiles as cron jobs

Note that `setcap` only applies to a specific binary. After running `self-update` command for restic/resticprofile, run the `setcap` command again.
