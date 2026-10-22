locals {
  blackbox_ports = {
    api = 9115
  }

  blackbox_config = file("${path.module}/blackbox.yml")

  blackbox_command = "/bin/sh -c 'while [ ! -f /etc/blackbox_exporter/cluster.yml ]; do sleep 1; done; exec /bin/blackbox_exporter --config.file=/etc/blackbox_exporter/cluster.yml --web.listen-address=:${local.blackbox_ports.api}'"
}

# Probes every service's health check through its public and private hostnames.
resource "incus_instance" "blackbox" {
  name = "blackbox"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "docker:prom/blackbox-exporter:v${var.versions.blackbox_exporter}"

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.blackbox.nic
  }

  file {
    content            = local.blackbox_config
    target_path        = "/etc/blackbox_exporter/cluster.yml"
    mode               = "0644"
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.entrypoint" = local.blackbox_command
  }
}

resource "null_resource" "blackbox_restart" {
  triggers = {
    command = sha1(local.blackbox_command)
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.blackbox.name}"
  }
}

resource "null_resource" "blackbox_reload" {
  triggers = {
    config = sha1(local.blackbox_config)
  }

  # the exporter may not be listening yet right after the instance is created
  provisioner "local-exec" {
    command = "incus exec ${incus_instance.blackbox.name} -- sh -c 'for i in $(seq 30); do wget -qO- --post-data= http://127.0.0.1:${local.blackbox_ports.api}/-/reload && exit 0; sleep 1; done; exit 1'"
  }
}
