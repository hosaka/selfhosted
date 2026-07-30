#cloud-config
users:
  - name: root
    ssh_authorized_keys:
      - ${ssh_key}

write_files:
  - path: /etc/apt/sources.list.d/linbit.sources
    content: |
      Types: deb
      URIs: https://packages.linbit.com/public
      Suites: proxmox-9
      Components: drbd-9
      Architectures: amd64
      Signed-By: /etc/apt/keyrings/linbit.asc
  - path: /etc/apt/keyrings/linbit.asc
    content: |${linbit_key}

package_update: true
package_upgrade: false

packages:
  - linstor-client
  - linstor-controller
  - openssh-server
  - python3-setuptools

runcmd:
  - systemctl enable --now ssh
  - systemctl enable --now linstor-controller
