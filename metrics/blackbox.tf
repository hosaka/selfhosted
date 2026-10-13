locals {
  blackbox_ports = {
    api = 9115
  }

  blackbox_config = file("${path.module}/blackbox.yml")
}

# Probes every service's health check through its public and private hostnames.
resource "incus_instance" "blackbox" {
  name = "blackbox"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:prom/blackbox-exporter:v${var.versions.blackbox_exporter}"

  file {
    content            = local.blackbox_config
    target_path        = "/etc/blackbox_exporter/config.yml"
    mode               = "0644"
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /etc/blackbox_exporter/config.yml ]; do sleep 1; done; exec /bin/blackbox_exporter --config.file=/etc/blackbox_exporter/config.yml --web.listen-address=:${local.blackbox_ports.api}'"

    "user.access_interface" = "eth0"
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
