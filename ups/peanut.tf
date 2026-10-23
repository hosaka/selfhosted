locals {
  peanut_ports = {
    webui = 8080
  }

  # read-only, without a upsd user it can't run commands on the UPS
  peanut_environment = {
    "environment.NUT_HOST"              = var.address
    "environment.NUT_PORT"              = local.nut_ports.upsd
    "environment.AUTH_DISABLED"         = "true"
    "environment.DISABLE_CONFIG_FILE"   = "true"
    "environment.DISABLE_VERSION_CHECK" = "true"
  }
}

# Dashboard for the UPS, and its numeric NUT variables as Prometheus metrics
resource "incus_instance" "peanut" {
  name = "peanut"
  type = "container"

  target   = var.target
  profiles = ["default", "oci"]
  image    = "docker:brandawg93/peanut:${var.versions.peanut}"

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.peanut.nic
  }

  wait_for {
    type = "ipv4"
  }

  config = local.peanut_environment
}

resource "null_resource" "peanut_restart" {
  triggers = {
    config = sha1(jsonencode(local.peanut_environment))
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.peanut.name}"
  }
}
