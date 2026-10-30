
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'fdca:6dc5:8573::/48'
	option packet_steering '1'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'lan1'
	list ports 'lan2'
	list ports 'lan3'
	list ports 'lan4'
	list ports '10g-2'
	option igmp_snooping '0'
	option multicast_querier '0'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '${address}'
	option netmask '${netmask}'
	list dns '127.0.0.1'
	list dns '0::1'
	option dns_metric '20'
	option ip6assign '0'

config interface 'wan6'
	option proto 'dhcpv6'
	option device '10g-1'
	option reqaddress 'try'
	option reqprefix 'auto'
	option norelease '1'
	option peerdns '0'
	list dns '0::1'

config interface 'wan'
	option proto 'dhcp'
	option device '10g-1'

config route
	option interface 'lan'
	option target '${ovn_network}'
	option netmask '${ovn_netmask}'
	option gateway '${ovn_router}'

