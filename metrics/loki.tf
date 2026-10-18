locals {
  loki_ports = {
    api = 3100
  }

  loki_command = join(" ", [
    "/usr/bin/loki",
    "-config.file=/etc/loki/local-config.yaml",
    "-compactor.retention-enabled=true",
    "-compactor.delete-request-store=filesystem",
    "-store.retention=720h",
    "-log.level=warn",
    # ranking caddy's access log per host and path needs one series per path, more than the default 500 over a day
    "-querier.max-query-series=5000",
  ])
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
  profiles = ["default", "oci"]
  image    = "docker:grafana/loki:${var.versions.loki}"

  # note: custom config file can be added to /etc/loki/local-config.yaml

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
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.loki.nic
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.entrypoint" = local.loki_command
  }
}

resource "null_resource" "loki_restart" {
  triggers = {
    command = sha1(local.loki_command)
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.loki.name}"
  }
}

resource "incus_server" "loki" {
  config = {
    "logging.loki.target.type"    = "loki"
    "logging.loki.target.address" = "http://${var.addresses.loki.ipv4}:${local.loki_ports.api}"
  }
}
