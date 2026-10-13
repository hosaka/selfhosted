# Restic backups

1. Install [restic](https://github.com/restic/restic) and [resticprofile](https://github.com/creativeprojects/resticprofile) on the host machine
2. Follow the docs on [preparing a new repository](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html), also see below for info on repository secrets
3. Configure restic for [rootless backups](https://restic.readthedocs.io/en/stable/080_examples.html#backing-up-your-system-without-running-restic-as-root) using `setcap`
4. Link this directory to `/usr/local/etc/resticprofile`
5. Run resticprofile with `doas -u restic resticprofile` (alias it to something like rst)
6. resticprofile will automatically pickup the `profiles.yaml`
7. Use `resticprofile schedule --all` to add schedule all profiles as cron jobs

Note that `setcap` only applies to a specific binary. After running `self-update` command for restic/resticprofile, run the `setcap` command again (only for restic itself) and chmod the updated binary (both restic and resticprofile) to 750.

```bash
cd /usr/local/bin
restic self-update && resticprofile self-update
chown root:restic restic{,profile}
chmod 750 restic{,profile}
setcap cap_dac_read_search=+ep restic{,profile}
```

## Repository secrets

Restic repository and remote storage keys are configured with a single [default.env](default.env). This env file is encrypted using [SOPS](https://getsops.io/docs/) and must be decrypted first before it can be used: `sops decrypt default.env > .env`. The resulting `.env` is sourced by `resticprofile` from the linked profile path configured in the step 4 above. You might want to chown this file to the restic user and chmod it to 400.

