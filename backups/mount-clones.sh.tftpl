#!/bin/sh
# Mounts a consistent copy of each LINSTOR volume given read-only under ${apps_path},
# a snapshot, a zfs clone of it, and the clone attached to this container.
set -eu

# whatever a failed or crashed run left behind
/usr/local/bin/unmount-clones "$@"

for v in "$@"; do
  incus storage volume snapshot create linstor "$v" backup --reuse
  incus storage volume copy "linstor/$v/backup" "linstor/backup-$v"
  incus config device add "${instance}" "src-$v" disk pool=linstor source="backup-$v" path="${apps_path}/$v" readonly=true
done
