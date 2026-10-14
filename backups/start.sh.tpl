#!/bin/sh
set -eu

# files are pushed after the container starts
for f in ${join(" ", formatlist("\"%s\"", wait_for))}; do
  while [ ! -f "$f" ]; do sleep 1; done
done

# standalone incus client, cached on the data volume until the version changes
bin="${data_path}/bin/incus-${incus_version}"
if [ ! -x "$bin" ]; then
  mkdir -p "${data_path}/bin"
  rm -f "${data_path}"/bin/incus-*
  curl -fsSL -o "$bin.tmp" "https://github.com/lxc/incus/releases/download/v${incus_version}/bin.linux.incus.x86_64"
  echo "${incus_sha256}  $bin.tmp" | sha256sum -c -
  chmod 0755 "$bin.tmp"
  mv "$bin.tmp" "$bin"
fi
ln -sf "$bin" /usr/local/bin/incus

# initialise the nas repository
if grep -q " ${nas_repo} " /proc/mounts && [ ! -f "${nas_repo}/config" ]; then
  RESTIC_PASSWORD_FILE="${nas_password}" restic init --repo "${nas_repo}"
fi

exec /docker-entrypoint /backrest
