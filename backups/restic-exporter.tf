locals {
  restic_exporter_ports = {
    metrics = 8001
  }
}

# Latest snapshots from backrest plans and the repository stats.
resource "incus_instance" "restic_exporter_nas" {
  name = "restic-exporter-nas"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:ngosang/restic-exporter:${var.versions.restic_exporter}"

  # the exporter does not write to the repository
  device {
    name = "restic"
    type = "disk"
    properties = {
      path     = local.nas_repo
      pool     = incus_storage_volume.restic.pool
      source   = incus_storage_volume.restic.name
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
      hwaddr         = "10:66:6a:e8:a1:2f"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.RESTIC_REPOSITORY" = local.nas_repo
    "environment.RESTIC_PASSWORD"   = sensitive(var.secrets.restic_password)
    "environment.TZ"                = var.timezone

    # backrest already checks the repository weekly
    "environment.NO_CHECK" = "true"

    "user.access_interface" = "eth1"
  }
}

resource "incus_instance" "restic_exporter_s3" {
  name = "restic-exporter-s3"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:ngosang/restic-exporter:${var.versions.restic_exporter}"

  device {
    name = "eth1"
    type = "nic"
    properties = {
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
      hwaddr         = "10:66:6a:97:c6:a8"
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "environment.RESTIC_REPOSITORY"     = sensitive(var.secrets.s3_repository)
    "environment.RESTIC_PASSWORD"       = sensitive(var.secrets.restic_password)
    "environment.AWS_ACCESS_KEY_ID"     = sensitive(var.secrets.s3_access_key_id)
    "environment.AWS_SECRET_ACCESS_KEY" = sensitive(var.secrets.s3_secret_access_key)
    "environment.TZ"                    = var.timezone

    # backrest already checks the repository monthly, and a full check would download the data
    "environment.NO_CHECK" = "true"

    "user.access_interface" = "eth1"
  }
}
