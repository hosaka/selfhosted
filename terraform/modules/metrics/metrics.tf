variable "grafana_version" {
  type    = string
  default = "13.1.1"
}

variable "prometheus_version" {
  type    = string
  default = "3.13.2"
}

variable "loki_version" {
  type    = string
  default = "3.7.4"
}

variable "metrics_port" {
  type    = string
  default = "8444"
}

data "incus_cluster" "this" {}

locals {
  metrics_targets = {
    for name, member in data.incus_cluster.this.members :
    name => "${split(":", trimprefix(member.address, "https://"))[0]}:${var.metrics_port}"
  }
}

# todo: add smartctl-exporter that runs on the node that controls the storage

# Each node will expose it's own metrics that can be scraped using prometheus.
# In order for prometheus to authenticate against the /1.0/metrics endpoint a
# metrics.crt and metric.key file need to be present in the container.
resource "incus_server" "metrics" {
  for_each = data.incus_cluster.this.members
  target   = data.incus_cluster.this.is_clustered ? each.key : null

  config = {
    "core.metrics_address" = ":${var.metrics_port}"
  }
}

resource "incus_storage_volume" "grafana_data" {
  name = "grafana-data"
  pool = var.storage

  config = {
    "initial.uid" = "472"
    "initial.gid" = "0"
  }
}

resource "incus_instance" "grafana" {
  depends_on = [incus_server.metrics]

  name = "grafana"
  type = "container"

  target   = var.target
  profiles = concat(var.profiles, ["lan"])
  image    = "docker:grafana/grafana:${var.grafana_version}"

  file {
    content            = file("${path.module}/datasources.yml")
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
    content = templatefile("${path.module}/grafana.ini.tpl", {
      public_domain = var.public_domain

      security_admin_user     = var.config.security_admin_user
      security_admin_password = sensitive(var.config.security_admin_password)
      oidc_client_id          = var.config.oidc_client_id
      oidc_client_secret      = sensitive(var.config.oidc_client_secret)
    })

    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/grafana.ini"
    mode               = "0600"
    create_directories = true
  }

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/var/lib/grafana"
      pool   = var.storage
      source = incus_storage_volume.grafana_data.name
    }
  }

  config = {
    "limits.memory" = "1536MiB"
  }
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
  depends_on = [incus_server.metrics]

  name = "prometheus"
  type = "container"

  target   = var.target
  profiles = var.profiles
  image    = "ghcr:prometheus/prometheus:v${var.prometheus_version}"

  file {
    content = templatefile("${path.module}/prometheus.yml.tpl", {
      metrics_targets = local.metrics_targets
    })

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
      pool   = var.storage
      source = incus_storage_volume.prometheus_data.name
    }
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /etc/prometheus/prometheus.yml ]; do sleep 1; done; exec /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=30d --storage.tsdb.retention.size=10GB --web.console.templates=/usr/share/prometheus/consoles --web.console.libraries=/usr/share/prometheus/console_libraries --web.enable-lifecycle'"
  }
}

resource "incus_storage_volume" "loki_data" {
  name = "loki-data"
  pool = var.storage

  config = {
    "initial.uid" = "10001"
    "initial.gid" = "10001"
  }
}

resource "incus_instance" "loki" {
  name     = "loki"
  type     = "container"
  target   = var.target
  profiles = concat(var.profiles, ["lan"])

  image = "docker:grafana/loki:${var.loki_version}"

  # custom config file can be added to /etc/loki/local-config.yaml

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/loki"
      pool   = var.storage
      source = incus_storage_volume.loki_data.name
    }
  }
}

resource "incus_server" "loki" {
  depends_on = [incus_instance.loki]

  config = {
    "logging.loki.target.type"    = "loki"
    "logging.loki.target.address" = "http://10.10.0.115:3100"
  }
}

