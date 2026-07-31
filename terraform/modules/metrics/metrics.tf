variable "prometheus_version" {
  type    = string
  default = "3.13.2"
}

resource "incus_storage_volume" "prometheus_data" {
  name = "prometheus-data"
  pool = var.storage

  config = {
    "initial.uid" = "65534"
    "initial.gid" = "65534"
  }
}

resource "incus_instance" "prometheus" {
  name = "prometheus"
  type = "container"

  target   = var.target
  profiles = var.profiles
  image    = "ghcr:prometheus/prometheus:v${var.prometheus_version}"

  file {
    content            = file("${path.module}/prometheus.yml")
    target_path        = "/etc/prometheus/prometheus.yml"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/node_rules.yml")
    target_path        = "/etc/prometheus/rules/node_rules.yml"
    mode               = "0600"
    create_directories = true
  }

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/prometheus"
      pool   = var.storage
      source = incus_storage_volume.prometheus_data.name
    }
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /etc/prometheus/prometheus.yml ]; do sleep 1; done; exec /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=30d --storage.tsdb.retention.size=10GB --web.console.templates=/usr/share/prometheus/consoles --web.console.libraries=/usr/share/prometheus/console_libraries --web.enable-lifecycle'"
  }
}
