#!/bin/sh
# Undoes mount-clones in reverse (device, clone, snapshot), skipping whatever doesn't exist,
# so it also cleans up after a run that failed half-way.
rc=0

for v in ${join(" ", volumes)}; do
  if incus config device show ${instance} | grep -q "^src-$v:"; then
    incus config device remove ${instance} "src-$v" || rc=1
  fi
  if incus storage volume show linstor "backup-$v" >/dev/null 2>&1; then
    incus storage volume delete linstor "backup-$v" || rc=1
  fi
  if incus storage volume snapshot show linstor "$v" backup >/dev/null 2>&1; then
    incus storage volume snapshot delete linstor "$v" backup || rc=1
  fi
done

exit $rc
