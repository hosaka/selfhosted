output "northbound_connection" {
  description = "OVN northbound database, what Incus connects to"
  value       = local.northbound

  depends_on = [incus_instance.ovn_central]
}

output "southbound_connection" {
  description = "OVN southbound database, what the IncusOS chassis connect to"
  value       = local.southbound

  depends_on = [incus_instance.ovn_central]
}

output "network" {
  description = "OVN network for instance NICs"
  value       = incus_network.ovn.name
}
