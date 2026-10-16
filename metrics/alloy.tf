locals {
  alloy_ports = {
    api    = 12345
    syslog = 1514
  }

  alloy_hwaddrs = {
    "node-1" = "10:66:6a:7d:c3:b0"
    "node-2" = "10:66:6a:16:ee:a9"
    "node-3" = "10:66:6a:04:a8:c4"
    "node-4" = "10:66:6a:fc:35:7e"
  }

  alloy_configs = {
    for node in var.log_collectors :
    node => templatefile("${path.module}/alloy.alloy.tpl", {
      node        = node
      loki_url    = "http://${incus_instance.loki.ipv4_address}:${local.loki_ports.api}/loki/api/v1/push"
      syslog_port = local.alloy_ports.syslog
    })
  }
}

# Each member runs an Alloy that tails the console output LXC writes for every
# instance into the logs directory, which is mounted read only.
resource "incus_instance" "alloy" {
  for_each = var.log_collectors

  name = "alloy-${each.key}"
  type = "container"

  target   = each.key
  profiles = ["default"]
  image    = "docker:grafana/alloy:v${var.versions.alloy}"

  device {
    name = "logs"
    type = "disk"
    properties = {
      path     = "/logs"
      pool     = "local"
      source   = "logs"
      readonly = "true"
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = local.alloy_hwaddrs[each.key]
    }
  }

  file {
    content            = local.alloy_configs[each.key]
    target_path        = "/etc/alloy/cluster.alloy"
    mode               = "0644"
    create_directories = true
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    # files are pushed after the instance starts
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /etc/alloy/cluster.alloy ]; do sleep 1; done; exec /bin/alloy run /etc/alloy/cluster.alloy --storage.path=/var/lib/alloy/data --server.http.listen-addr=0.0.0.0:${local.alloy_ports.api}'"

    "user.access_interface" = "eth1"
  }
}

# alloy keeps its read positions in its storage path, so a restart picks up where it left off
resource "null_resource" "alloy_restart" {
  for_each = var.log_collectors

  triggers = {
    config = sha1(local.alloy_configs[each.key])
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.alloy[each.key].name}"
  }
}

# IncusOS forwards each member's journal to the alloy on that member, the provider has no resource for this IncusOS API.
# UDP because the systemd-netlogd in IncusOS doesn't have rfc5425 nor separates messages over TCP.
resource "null_resource" "host_syslog" {
  for_each = var.log_collectors

  triggers = {
    target = each.key
    config = jsonencode({
      config = {
        syslog = {
          address    = "${incus_instance.alloy[each.key].ipv4_address}:${local.alloy_ports.syslog}"
          protocol   = "udp"
          log_format = "rfc5424"
        }
      }
    })
  }

  provisioner "local-exec" {
    command = "incus query -X PUT --data '${self.triggers.config}' '/os/1.0/system/logging?target=${self.triggers.target}'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "incus query -X PUT --data '{\"config\": {}}' '/os/1.0/system/logging?target=${self.triggers.target}'"
  }
}
