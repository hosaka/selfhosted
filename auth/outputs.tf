output "probes" {
  value = [
    "https://auth.${var.public_domain}/api/health",
    "https://users.${var.private_domain}/health",
  ]
}

output "backups" {
  value = {
    authelia = {
      volumes = {
        (incus_storage_volume.authelia_db.name) = {}
      }
      databases = [incus_instance.authelia_database.name]
    }

    lldap = {
      volumes = {
        (incus_storage_volume.lldap_data.name) = {}
      }
    }
  }
}

output "ingress" {
  value = {
    name  = "auth"
    caddy = <<-EOT
			auth.${var.public_domain} {
				reverse_proxy ${var.addresses.authelia.ipv4}:${local.authelia_ports.api}
			}
			users.${var.private_domain} {
				reverse_proxy ${var.addresses.lldap.ipv4}:${local.lldap_ports.webui}
			}
    EOT
  }
}

output "authelia_address" {
  description = "Authelia's API endpoint, only reachable inside the cluster"
  value       = "${var.addresses.authelia.ipv4}:${local.authelia_ports.api}"
}

output "authelia_metrics_address" {
  description = "Authelia's prometheus metrics endpoint, only reachable inside the cluster"
  value       = "${var.addresses.authelia.ipv4}:${local.authelia_ports.metrics}"
}

output "lldap_address" {
  description = "LLDAP's LDAP endpoint, not exposed through Caddy"
  value       = "${var.addresses.lldap.ipv4}:${local.lldap_ports.ldap}"
}

output "lldap_base_dn" {
  value = local.lldap_base_dn
}
