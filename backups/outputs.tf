output "probes" {
  value = [
    "https://backup.${var.private_domain}/",
  ]
}

output "ingress" {
  value = {
    name  = "backup"
    caddy = <<-EOT
			backup.${var.private_domain} {
				reverse_proxy ${var.addresses.backrest.ipv4}:${local.backrest_ports.webui}
			}
    EOT
  }
}

output "restic_exporter_addresses" {
  description = "restic-exporter's metrics endpoint by restic repository, only reachable inside the cluster"
  value = {
    nas = "${var.addresses.restic_exporter_nas.ipv4}:${local.restic_exporter_ports.metrics}"
    s3  = "${var.addresses.restic_exporter_s3.ipv4}:${local.restic_exporter_ports.metrics}"
  }
}

output "schedules" {
  description = "Cron schedule of each repository's backup plans"
  value       = { for name, repo in local.repos : name => repo.schedule }
}
