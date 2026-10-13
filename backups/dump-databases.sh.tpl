#!/bin/sh
# Dumps each Postgres instance into ${dumps_path}, as plain SQL so consecutive dumps dedup.
# The instances own POSTGRES_USER is used, over the local socket.
set -eu

mkdir -p ${dumps_path}

for db in ${join(" ", databases)}; do
  incus exec "$db" -- sh -c 'pg_dumpall -c -U "$POSTGRES_USER"' > "${dumps_path}/$db.sql.tmp"
  mv "${dumps_path}/$db.sql.tmp" "${dumps_path}/$db.sql"
done
