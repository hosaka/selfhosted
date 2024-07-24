# Restic backups

1. Install [restic](https://github.com/restic/restic) and [resticprofile](https://github.com/creativeprojects/resticprofile) on the host machine
2. Follow the docs on [preparing a new repository](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html), also see below for info on repository secrets
3. Configure restic for [rootless backups](https://restic.readthedocs.io/en/stable/080_examples.html#backing-up-your-system-without-running-restic-as-root) using `setcap`
4. Link this folder to `/usr/local/etc/resticprofile`
5. Run resticprofile with `doas -u restic resticprofile` (alias it to something like rst)
6. resticprofile will automatically pickup the `profiles.yaml`
7. Use `resticprofile schedule --all` to add schedule all profiles as cron jobs

Note that `setcap` only applies to a specific binary. After running `self-update` command for restic/resticprofile, run the `setcap` command again (only for restic itself) and chmod the updated binary (both restic and resticprofile) to 750.

## Repository secrets

A `.env` file is used and sourced by `resticprofile` that contains resticr epository secrets. See an example in [default.env](default.env).

1. Make a copy of `default.env` or create a new file in the home directory of a user that executes resticprofile binary. If rootless backups are configured as above, this will be `/home/restic/.env`. This path can also be modified in [conf.d/default.yaml](conf.d/default.yaml)
2. Make your changes to this `.env` file and chmod it to 400
3. Run `resticprofile` as usual or use scheduled backups
