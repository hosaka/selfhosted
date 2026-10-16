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

				reverse_proxy ${incus_instance.grafana.ipv4_address}:${local.grafana_ports.webui}
			}
    EOT
  }
}

output "prometheus_address" {
  description = "Prometheus API on the mesh network, only reachable inside the cluster."
  value       = "${incus_instance.prometheus.ipv4_address}:${local.prometheus_ports.api}"
}
