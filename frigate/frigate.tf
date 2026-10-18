locals {
  frigate_ports = {
    webui  = 5000
    rtsp   = 8554
    webrtc = 8555
  }
}

resource "incus_storage_volume" "frigate_data" {
  name = "frigate-data"
  pool = "linstor"
}

resource "incus_instance" "frigate" {
  name = "frigate"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "ghcr:blakeblackshear/frigate:${var.versions.frigate}"

  device {
    name = "config"
    type = "disk"
    properties = {
      path   = "/config"
      pool   = incus_storage_volume.frigate_data.pool
      source = incus_storage_volume.frigate_data.name
    }
  }

  device {
    name = "recordings"
    type = "disk"
    properties = {
      path   = "/media/frigate/recordings"
      pool   = var.storage_pool
      source = var.storage_source
    }
  }

  # hardware video decoding
  device {
    name = "gpu"
    type = "gpu"
    properties = {
      gputype = "physical"
    }
  }

  # Coral PCIe Edge TPUs, the host needs the gasket/apex driver for these to exist
  device {
    name = "coral0"
    type = "unix-char"
    properties = {
      source = "/dev/apex_0"
      path   = "/dev/apex_0"
    }
  }

  device {
    name = "coral1"
    type = "unix-char"
    properties = {
      source = "/dev/apex_1"
      path   = "/dev/apex_1"
    }
  }

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.frigate.nic
  }

  file {
    content = templatefile("${path.module}/config.yml.tpl", {
      mqtt_host        = var.mqtt_host
      mqtt_user        = var.secrets.mqtt_user
      mqtt_password    = sensitive(var.secrets.mqtt_password)
      camera_user      = var.secrets.camera_user
      camera1_host     = var.camera1_host
      camera1_password = sensitive(var.secrets.camera1_password)
      camera2_host     = var.camera2_host
      camera2_password = sensitive(var.secrets.camera2_password)
    })
    target_path = "/config/config.yml"
    mode        = "0600"
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    # frigate writes a default config when none exists, wait for ours to be pushed first
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -f /config/config.yml ]; do sleep 1; done; exec /init'"

    # recording segments are cached here before being moved to storage, keep them in memory
    "raw.lxc" = "lxc.mount.entry = tmpfs tmp/cache tmpfs rw,size=1000000000,create=dir 0 0"

    "environment.LIBVA_DRIVER_NAME" = "radeonsi"
    "environment.TZ"                = var.timezone
  }
}

output "ingress" {
  value = {
    name  = "frigate"
    caddy = <<-EOT
			frigate.${var.private_domain} {
				reverse_proxy ${var.addresses.frigate.ipv4}:${local.frigate_ports.webui}
			}
    EOT
  }
}
