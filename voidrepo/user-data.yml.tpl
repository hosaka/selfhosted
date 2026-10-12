#cloud-config
cloud_init_modules:
  - seed_random
  - bootcmd
  - write_files
  - growpart
  - resizefs
  - disk_setup
  - mounts
  - set_hostname
  - update_hostname
  - update_etc_hosts
  - resolv_conf
  - ca_certs
  - rsyslog
  - users_groups

ssh:
  emit_keys_to_console: false

package_update: true
package_upgrade: false

packages:
  - rsync

write_files:
  - path: /usr/local/bin/sync.sh
    permissions: "0755"
    content: |
      ${indent(6, sync_sh)}

  - path: /etc/crontabs/root
    append: true
    content: |
      ${cron_schedule} RSYNC_ARGS="${rsync_args}" /usr/local/bin/sync.sh 2>&1 | logger -t voidrepo

  # sync on every boot, in the background so a long sync doesn't block the boot
  - path: /etc/local.d/voidrepo.start
    permissions: "0755"
    content: |
      #!/bin/sh
      (RSYNC_ARGS="${rsync_args}" /usr/local/bin/sync.sh 2>&1 | logger -t voidrepo) &

runcmd:
  - rc-update add syslog boot
  - rc-service syslog start
  - rc-update add crond default
  - rc-service crond start
  - rc-update add local default
  - rc-service local start
