locals {
  grafana_ports = {
    webui = 3000
  }

  grafana_config = templatefile("${path.module}/grafana.ini.tpl", {
    public_domain      = var.public_domain
    oidc_client_id     = var.secrets.oidc_client_id
    oidc_client_secret = sensitive(var.secrets.oidc_client_secret)
  })

  grafana_datasources = templatefile("${path.module}/datasources.yml.tpl", {
    prometheus_address = var.addresses.prometheus.ipv4
    prometheus_port    = local.prometheus_ports.api
    loki_address       = var.addresses.loki.ipv4
    loki_port          = local.loki_ports.api
  })
}

resource "incus_storage_volume" "grafana_data" {
  name = "grafana-data"
  pool = "linstor"

  config = merge({
    "initial.uid" = "472"
    "initial.gid" = "0"
  }, var.snapshots)
}

resource "incus_instance" "grafana" {
  name = "grafana"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "docker:grafana/grafana:${var.versions.grafana}"

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.grafana.nic
  }

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
    content            = local.grafana_notifications
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/alerting/notifications.yml"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = local.grafana_alert_rules
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/alerting/rules.yml"
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
    content            = file("${path.module}/dashboards/incus-overview.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/incus-overview.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/linstor-pool.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/linstor-pool.json"
    mode               = "0600"
    create_directories = true
  }
  file {
    content            = file("${path.module}/dashboards/incus-logs.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/incus-logs.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/instance-logs.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/instance-logs.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/caddy-monitor.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/caddy-monitor.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/drive-health.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/drive-health.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/tunnel-metrics.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/tunnel-metrics.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/authelia.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/authelia.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/monitoring.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/monitoring.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/immich.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/immich.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/uptime.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/uptime.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/backups.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/backups.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/dashboards/ups-monitor.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/provisioning/dashboards/ups-monitor.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/home.json")
    uid                = 472
    gid                = 0
    target_path        = "/etc/grafana/home.json"
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
}

resource "null_resource" "grafana_restart" {
  triggers = {
    config        = nonsensitive(sha1(local.grafana_config))
    datasources   = sha1(local.grafana_datasources)
    notifications = nonsensitive(sha1(local.grafana_notifications))
    alert_rules   = sha1(local.grafana_alert_rules)
  }

  provisioner "local-exec" {
    command = "incus restart grafana"
  }

  depends_on = [incus_instance.grafana]
}
