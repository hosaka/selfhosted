
config dnsmasq
	option domainneeded '1'
	option localise_queries '1'
	option rebind_protection '1'
	option rebind_localhost '1'
	option local '/lan/'
	option expandhosts '1'
	option cachesize '1000'
	option authoritative '1'
	option readethers '1'
	option leasefile '/tmp/dhcp.leases'
	option localservice '0'
	option ednspacket_max '1232'
	list addnmount '/bin/busybox'
	list addnmount '/var/run/adblock-lean/abl-blocklist.gz'
	list server '127.0.0.1#5453'
	list server '0::1#5453'
	option localuse '0'
	option noresolv '1'
	option strictorder '1'
	list address '/${cluster.name}.${public_domain}/${cluster.node-1.ipv4_address}'
	list address '/${cluster.node-1.target}.${public_domain}/${cluster.node-1.ipv4_address}'
	list address '/${cluster.node-2.target}.${public_domain}/${cluster.node-2.ipv4_address}'
	list address '/${cluster.node-3.target}.${public_domain}/${cluster.node-3.ipv4_address}'
	list address '/${cluster.node-4.target}.${public_domain}/${cluster.node-4.ipv4_address}'
	list address '/eth.${public_domain}/${tessier_address}'
	list address '/${private_domain}/${caddy_address}'
	list address '/cloud.${public_domain}/${caddy_address}'

config dhcp 'lan'
	option interface 'lan'
	option start '100'
	option limit '130'
	option leasetime '12h'
	option dhcpv6 'relay'
	option ra 'relay'
	option ndp 'relay'

config odhcpd 'odhcpd'
	option maindhcp '0'
	option leasefile '/tmp/hosts/odhcpd'
	option leasetrigger '/usr/sbin/odhcpd-update'
	option loglevel '4'

config dhcp 'wan6'
	option interface 'wan6'
	option ignore '1'
	option master '1'
	option ra 'relay'
	option dhcpv6 'relay'
	option ndp 'relay'

config host
	option name 'tessier'
	option ip '${tessier_address}'
	option mac 'A8:A1:59:50:CA:6B'

config host
	option name '${cluster.node-1.target}'
	option ip '${cluster.node-1.ipv4_address}'
	option leasetime 'infinite'
	list mac '8C:A6:82:71:9C:6D'
	list mac '00:2B:67:10:3E:EE'

config host
	option name '${cluster.node-2.target}'
	option ip '${cluster.node-2.ipv4_address}'
	option leasetime 'infinite'
	list mac '8C:A6:82:71:9B:96'
	list mac '00:2b:67:10:34:16'

config host
	option name '${cluster.node-3.target}'
	option ip '${cluster.node-3.ipv4_address}'
	option leasetime 'infinite'
	list mac '8C:A6:82:71:9B:9A'
	list mac '98:fa:9b:9d:77:65'

config host
	option name '${cluster.node-4.target}'
	option ip '${cluster.node-4.ipv4_address}'
	list mac 'D8:5E:D3:FC:77:70'
	option leasetime 'infinite'

config host
	option name 'linstor-controller'
	option ip '10.10.0.173'
	option leasetime 'infinite'
	list mac '10:66:6A:3F:16:7A'

