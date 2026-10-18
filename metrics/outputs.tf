output "probes" {
  value = [
    "https://metrics.${var.public_domain}/api/health",
  ]
}

output "backups" {
  value = {
    grafana = {
      volumes = {
        (incus_storage_volume.grafana_data.name) = {}
      }
    }
  }
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

				reverse_proxy ${var.addresses.grafana.ipv4}:${local.grafana_ports.webui}
			}
    EOT
  }
}

output "prometheus_address" {
  description = "Prometheus API on the mesh network, only reachable inside the cluster."
  value       = "${var.addresses.prometheus.ipv4}:${local.prometheus_ports.api}"
}
