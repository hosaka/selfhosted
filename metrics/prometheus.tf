locals {
  prometheus_ports = {
    api = 9090
  }

  metrics_targets = {
    for name, member in var.members :
    name => "${split(":", trimprefix(member.address, "https://"))[0]}:${var.port}"
  }

  prometheus_command = "/bin/sh -c 'while [ ! -f /etc/prometheus/prometheus.yml ]; do sleep 1; done; exec /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=30d --storage.tsdb.retention.size=10GB --web.console.templates=/usr/share/prometheus/consoles --web.console.libraries=/usr/share/prometheus/console_libraries --web.enable-lifecycle --log.level=warn'"

  prometheus_config = templatefile("${path.module}/prometheus.yml.tpl", {
    metrics_targets  = local.metrics_targets
    smartctl_targets = local.smartctl_targets
    linstor_target   = var.linstor_address
    authelia_target  = var.authelia_address
    immich_targets   = var.immich_addresses
    restic_targets   = var.restic_exporter_addresses
    blackbox_target  = "${var.addresses.blackbox.ipv4}:${local.blackbox_ports.api}"
    probes = flatten([
      for service, urls in var.probes : [
        for url in urls : {
          service = service
          url     = url
          domain  = endswith(regex("^https://([^/]+)", url)[0], var.private_domain) ? "private" : "public"
        }
      ]
    ])
    prometheus_port = local.prometheus_ports.api
    loki_target     = "${var.addresses.loki.ipv4}:${local.loki_ports.api}"
    alloy_targets = {
      for node in var.log_collectors :
      node => "${var.addresses["alloy-${node}"].ipv4}:${local.alloy_ports.api}"
    }
  })
}

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
  profiles = ["default", "oci"]
  image    = "ghcr:prometheus/prometheus:v${var.versions.prometheus}"

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.prometheus.nic
  }

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

  file {
    content            = sensitive(var.secrets.frps_user)
    target_path        = "/etc/prometheus/secrets/frps_user"
    uid                = 65534
    gid                = 65534
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = sensitive(var.secrets.frps_password)
    target_path        = "/etc/prometheus/secrets/frps_password"
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

  wait_for {
    type = "ipv4"
  }

  config = {
    // enable-lifecycle allows reloading config by POSTing to `/-/reload`
    "oci.entrypoint" = local.prometheus_command
  }

  depends_on = [incus_server.metrics, incus_certificate.metrics_key]
}

# incus only uses a changed entrypoint on the next start
resource "null_resource" "prometheus_restart" {
  triggers = {
    command = sha1(local.prometheus_command)
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.prometheus.name}"
  }
}

# Addresses from the ingress module can't go into prometheus.yml: caddy's config contains grafana's address,
# and grafana's datasources contain prometheus address, which would cause a dependency cycle.
# Prometheus watches these files instead.
resource "null_resource" "ingress_targets" {
  for_each = {
    caddy = var.caddy_address
    frps  = var.frps_address
  }

  triggers = {
    targets = jsonencode([{ targets = [each.value] }])
  }

  lifecycle {
    replace_triggered_by = [incus_instance.prometheus]
  }

  provisioner "local-exec" {
    command = "printf '%s' '${self.triggers.targets}' | incus exec ${incus_instance.prometheus.name} -- sh -c 'mkdir -p /etc/prometheus/targets && cat > /etc/prometheus/targets/${each.key}.json'"
  }
}

resource "null_resource" "prometheus_reload" {
  triggers = {
    config = sha1(local.prometheus_config)
  }

  provisioner "local-exec" {
    command = "incus exec prometheus -- sh -c 'for i in $(seq 30); do wget -qO- --post-data= http://127.0.0.1:${local.prometheus_ports.api}/-/reload && exit 0; sleep 1; done; exit 1'"
  }

  depends_on = [incus_instance.prometheus]
}
