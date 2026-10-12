locals {
  metrics_ports = {
    webui      = 3000
    prometheus = 9090
    loki       = 3100
  }

  metrics_targets = {
    for name, member in var.members :
    name => "${split(":", trimprefix(member.address, "https://"))[0]}:${var.port}"
  }

  grafana_config = templatefile("${path.module}/grafana.ini.tpl", {
    public_domain      = var.public_domain
    oidc_client_id     = var.secrets.oidc_client_id
    oidc_client_secret = sensitive(var.secrets.oidc_client_secret)
  })

  grafana_datasources = templatefile("${path.module}/datasources.yml.tpl", {
    prometheus_address = incus_instance.prometheus.ipv4_address
    prometheus_port    = local.metrics_ports.prometheus
    loki_address       = incus_instance.loki.ipv4_address
    loki_port          = local.metrics_ports.loki
  })

  prometheus_config = templatefile("${path.module}/prometheus.yml.tpl", {
    metrics_targets = local.metrics_targets
  })
}

# todo: add smartctl-exporter that runs on the node that controls the storage

# Each node will expose it's own metrics that can be scraped using prometheus.
# In order for prometheus to authenticate against the /1.0/metrics endpoint a
# metrics.crt and metric.key file need to be present in the container.
resource "incus_server" "metrics" {
  for_each = var.members
  target   = each.key

  config = {
    "core.metrics_address" = ":${var.port}"
  }
}

resource "incus_storage_volume" "grafana_data" {
  name = "grafana-data"
  pool = "linstor"

  config = {
    "initial.uid" = "472"
    "initial.gid" = "0"
  }
}

resource "incus_instance" "grafana" {
  name = "grafana"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "docker:grafana/grafana:${var.versions.grafana}"

  file {
    content            = local.grafana_datasources
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/datasources/datasources.yml"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards.yml")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/dashboards.yml"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/incus.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/incus.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = local.grafana_config
    target_path        = "/etc/grafana/grafana.ini"
    uid                = 472
    gid                = 0
    mode               = "0600"
    create_directories = true
  }

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/var/lib/grafana"
      pool   = incus_storage_volume.grafana_data.pool
      source = incus_storage_volume.grafana_data.name
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "user.access_interface" = "eth1"
  }
}

resource "null_resource" "grafana_restart" {
  triggers = {
    config      = nonsensitive(sha1(local.grafana_config))
    datasources = sha1(local.grafana_datasources)
  }

  provisioner "local-exec" {
    command = "incus restart grafana"
  }

  depends_on = [incus_instance.grafana]
}

resource "incus_storage_volume" "prometheus_data" {
  name = "prometheus-data"
  pool = "linstor"

  config = {
    "initial.uid" = "65534"
    "initial.gid" = "65534"
  }
}

resource "incus_certificate" "metrics_key" {
  name        = "metrics"
  type        = "metrics"
  description = "Prometheus metrics"
  certificate = file("${path.module}/metrics.crt")
  # can be optionally restircted to a list of projects
  # restricted = true
  # projects   = ["metrics"]
}

resource "incus_instance" "prometheus" {
  name = "prometheus"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:prometheus/prometheus:v${var.versions.prometheus}"

  file {
    content            = local.prometheus_config
    target_path        = "/etc/prometheus/prometheus.yml"
    uid                = 65534
    gid                = 65534
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/metrics.crt")
    target_path        = "/etc/prometheus/tls/metrics.crt"
    uid                = 65534
    gid                = 65534
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = sensitive(file("${path.module}/metrics.key"))
    target_path        = "/etc/prometheus/tls/metrics.key"
    uid                = 65534
    gid                = 65534
    mode               = "0600"
    create_directories = true
  }

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/prometheus"
      pool   = incus_storage_volume.prometheus_data.pool
      source = incus_storage_volume.prometheus_data.name
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "incusbr0"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    // enable-lifecycle allows reloading config by POSTing to `/-/reload`
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /etc/prometheus/prometheus.yml ]; do sleep 1; done; exec /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=30d --storage.tsdb.retention.size=10GB --web.console.templates=/usr/share/prometheus/consoles --web.console.libraries=/usr/share/prometheus/console_libraries --web.enable-lifecycle'"

    "user.access_interface" = "eth0"
  }

  depends_on = [incus_server.metrics, incus_certificate.metrics_key]
}

resource "null_resource" "prometheus_reload" {
  triggers = {
    config = sha1(local.prometheus_config)
  }

  # prometheus may not be listening yet right after the instance is created
  provisioner "local-exec" {
    command = "incus exec prometheus -- sh -c 'for i in $(seq 30); do wget -qO- --post-data= http://127.0.0.1:${local.metrics_ports.prometheus}/-/reload && exit 0; sleep 1; done; exit 1'"
  }

  depends_on = [incus_instance.prometheus]
}

resource "incus_storage_volume" "loki_data" {
  name = "loki-data"
  pool = "linstor"

  config = {
    "initial.uid" = "10001"
    "initial.gid" = "10001"
  }
}

resource "incus_instance" "loki" {
  name = "loki"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:grafana/loki:${var.versions.loki}"

  # custom config file can be added to /etc/loki/local-config.yaml

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/loki"
      pool   = incus_storage_volume.loki_data.pool
      source = incus_storage_volume.loki_data.name
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "meshbr0"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "user.access_interface" = "eth0"
  }
}

resource "incus_server" "loki" {
  config = {
    "logging.loki.target.type"    = "loki"
    "logging.loki.target.address" = "http://${incus_instance.loki.ipv4_address}:${local.metrics_ports.loki}"
  }
}

output "ingress" {
  value = {
    name  = "metrics"
    caddy = <<-EOT
			metrics.${var.public_domain} {
				reverse_proxy ${incus_instance.grafana.ipv4_address}:${local.metrics_ports.webui}
			}
    EOT
  }
}
