#!/bin/sh
# Restores a LINSTOR volume in place from the nas repo, replacing its contents with a snapshot's:
# stops the instances using it, attaches it here, restores, detaches it and starts them again.
# Paths the backup excludes (caches, logs, mirrors) are neither restored nor deleted.
set -eu

if [ $# -ne 2 ]; then
  echo "usage: restore-volume <volume> <snapshot ID|latest>" >&2
  exit 2
fi

volume=$1
source="${apps_path}/$volume"
target="${restore_path}/$volume"
device=restore-$volume
export RESTIC_REPOSITORY="${nas_repo}"
export RESTIC_PASSWORD_FILE="${restic_password}"

excludes=$(mktemp)
busy=
stopped=
cleanup() {
  rm -f "$excludes"
  if [ -n "$busy" ]; then
    echo "Restoring $volume failed, it's still attached here at $target." >&2
    if [ -n "$stopped" ]; then
      echo "Stopped by this run, start them once it's sorted:$stopped" >&2
    fi
    echo "Running restore-volume again retries the restore." >&2
  fi
}
trap cleanup EXIT

# the backup's excludes, relative to the volume
printf '%s\n' ${join(" ", formatlist("'%s'", excludes))} > "$excludes"
case "$volume" in
%{ for v, patterns in volumes ~}
  ${v})%{ if length(patterns) > 0 } printf '%s\n' ${join(" ", formatlist("'%s'", patterns))} >> "$excludes"%{ endif } ;;
%{ endfor ~}
  *)
    echo "$volume isn't backed up" >&2
    exit 1
    ;;
esac

# latest is the newest snapshot with the volume in it
snapshot=$(restic snapshots --no-lock --json --path "$source" "$2")
case "$snapshot" in
  *"\"$source\""*) ;;
  *)
    echo "Snapshot $2 doesn't have $volume in it" >&2
    exit 1
    ;;
esac
id=$(echo "$snapshot" | sed -n 's/.*"short_id":"\([0-9a-f]*\)".*/\1/p')
time=$(echo "$snapshot" | sed -n 's/.*"time":"\([^".]*\).*/\1/p')

instances=$(incus storage volume show linstor "$volume" | sed -n 's|^- /1.0/instances/\([^?]*\).*|\1|p' | grep -vx "${instance}" || true)

echo "This replaces the contents of $volume with snapshot $id from $time."
echo "Everything written to it since then is lost, except in excluded paths."
echo "Instances using it, stopped while it's restored and started again: $(echo "$instances" | tr '\n' ' ')"
printf 'Type the volume name to go ahead: '
answer=
read -r answer || true
if [ "$answer" != "$volume" ]; then
  echo "Aborted" >&2
  exit 1
fi

busy=1
for i in $instances; do
  if [ "$(incus list -f csv -c s "^$i\$")" = RUNNING ]; then
    incus stop "$i"
    stopped="$stopped $i"
  fi
done

if ! incus config device show "${instance}" | grep -q "^$device:"; then
  incus config device add "${instance}" "$device" disk pool=linstor source="$volume" path="$target"
fi
restic restore "$id:$source" --target "$target" --delete --exclude-file "$excludes"
incus config device remove "${instance}" "$device"

for i in $stopped; do
  incus start "$i"
done
busy=
echo "Restored $volume from $id"
