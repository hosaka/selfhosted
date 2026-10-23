#!/bin/sh
# upsmon's SHUTDOWNCMD. Powers off the other cluster members and waits until their Incus has stopped,
# then powers off ${self}.
#
# upsmon has set its POWERDOWNFLAG by now so when Incus stops this container, the last instance on ${self},
# NUT's systemd-shutdown hook tells the UPS to cut its output, and to turn it back on once power returns.
set -u

self=${self}
self_address=${self_address}

# The cluster certificate is only valid for 127.0.0.1 and the name of the member that created it,
# so curl checks it against 127.0.0.1 and connects to the member's address instead.
api() {
  curl --silent --show-error --fail --connect-timeout 5 --max-time 30 --request "$2" \
    --cacert ${incus_conf}/cluster.crt --cert ${incus_conf}/client.crt --key ${incus_conf}/client.key \
    --connect-to "127.0.0.1:443:$1" "https://127.0.0.1$3"
}

# name=address of every other member that is online
members=$(api "$self_address" GET '/1.0/cluster/members?recursion=1' | jq -r --arg self "$self" \
  '.metadata[] | select(.server_name != $self and .status == "Online") | "\(.server_name)=\(.url | ltrimstr("https://"))"')

# --dry-run reads every member's IncusOS API instead, which takes the same permission as powering it off
if [ "$${1:-}" = --dry-run ]; then
  status=0
  for member in $members "$self=$self_address"; do
    if api "$${member#*=}" GET /os/1.0 >/dev/null; then
      echo "would power off $${member%%=*}"
    else
      echo "can't use $${member%%=*}'s IncusOS API" >&2
      status=1
    fi
  done
  exit $status
fi

for member in $members; do
  echo "powering off $${member%%=*}"
  api "$${member#*=}" POST /os/1.0/system/:poweroff >/dev/null &
done
wait

# a member closes its API once it has stopped its instances and unmounted its storage
deadline=$(($(date +%s) + ${timeout}))
for member in $members; do
  while api "$${member#*=}" GET /1.0 >/dev/null 2>&1; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
      echo "stopped waiting for the other members after ${timeout}s" >&2
      break 2
    fi
    sleep 5
  done
  echo "$${member%%=*} is down"
done

echo "powering off $self"
api "$self_address" POST /os/1.0/system/:poweroff >/dev/null
