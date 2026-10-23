output "probes" {
  value = [
    "https://ups.${var.private_domain}/api/ping",
  ]
}

output "ingress" {
  value = {
    name  = "ups"
    caddy = <<-EOT
			ups.${var.private_domain} {
				reverse_proxy ${var.addresses.peanut.ipv4}:${local.peanut_ports.webui}
			}
    EOT
  }
}

output "peanut_address" {
  description = "PeaNUT's API, with Prometheus metrics on /api/v1/metrics, only reachable inside the cluster"
  value       = "${var.addresses.peanut.ipv4}:${local.peanut_ports.webui}"
}
