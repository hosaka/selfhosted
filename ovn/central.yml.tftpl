#cloud-config
write_files:
  - path: /etc/apt/sources.list.d/zabbly-ovn-stable.sources
    content: |
      Types: deb
      URIs: https://pkgs.zabbly.com/ovn/stable
      Suites: trixie
      Components: main
      Signed-By: /etc/apt/keyrings/zabbly.asc
  - path: /etc/apt/keyrings/zabbly.asc
    content: |
      ${indent(6, zabbly_key)}
  # the release series IncusOS runs, ovn-northd must not be newer than the ovn-controllers
  - path: /etc/apt/preferences.d/ovn
    content: |
      Package: ovn-*
      Pin: version 1:${ovn_version}.*
      Pin-Priority: 1001
  # read by /etc/init.d/ovn-central, has to be in place before the package starts it
  - path: /etc/default/ovn-central
    content: |
      OVN_CTL_OPTS=" \
        --db-nb-addr=${address} --db-nb-port=${northbound_port} --db-nb-create-insecure-remote=yes \
        --db-sb-addr=${address} --db-sb-port=${southbound_port} --db-sb-create-insecure-remote=yes \
        --db-nb-cluster-local-addr=${address} \
        --db-sb-cluster-local-addr=${address} \
%{ if first_address != "" ~}
        --db-nb-cluster-remote-addr=${first_address} \
        --db-sb-cluster-remote-addr=${first_address} \
%{ endif ~}
        --ovn-northd-nb-db=${northbound} \
        --ovn-northd-sb-db=${southbound}"

package_update: true
package_upgrade: false

packages:
  # ovsdb-server and the ovs-lib that ovn-ctl loads, ovn-central needs both but doesn't depend on them
  - openvswitch-common

runcmd:
  # after openvswitch-common, the postinst starts the databases and ovn-northd with the options above
  - DEBIAN_FRONTEND=noninteractive apt-get install -y ovn-central
