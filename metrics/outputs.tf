output "probes" {
  value = [
    "https://metrics.${var.public_domain}/api/health",
  ]
}

output "ingress" {
  value = {
    name  = "metrics"
    caddy = <<-EOT
			metrics.${var.public_domain} {
				# no need to log requests to ourselves
				log {
					output discard
				}

				reverse_proxy ${incus_instance.grafana.ipv4_address}:${local.grafana_ports.webui}
			}
    EOT
  }
}
