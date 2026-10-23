#cloud-config
# NUT's user and group with fixed ids, created before the package installs do
bootcmd:
  - getent group nut >/dev/null || groupadd --system --gid ${nut_id} nut
  - getent passwd nut >/dev/null || useradd --system --uid ${nut_id} --gid nut --home-dir /var/lib/nut --no-create-home --shell /usr/sbin/nologin nut

package_update: true
package_upgrade: false

packages:
  - nut-server
  - nut-client
  - curl
  - jq
