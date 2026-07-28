data "incus_cluster" "this" {
  remote = var.cluster.name
  lifecycle {
    postcondition {
      condition     = alltrue(self.is_clustered ? [for i, v in self.members : v.status == "Online"] : [])
      error_message = "All servers must be online."
    }
  }
}

resource "incus_profile" "default" {
  name        = "default"
  description = "Default Incus profile"

  config = {
    "limits.cpu"    = "1"
    "limits.memory" = "512MiB"
    # "snapshots.schedule" = "@daily"
    # "snapshots.expiry"   = "7d"
    "environment.TZ" = var.timezone
  }

  device {
    name = "eth0"
    properties = {
      nictype = "bridged"
      parent  = "incusbr0"
    }
    type = "nic"
  }

  device {
    name = "root"
    properties = {
      path = "/"
      pool = "local"
    }
    type = "disk"
  }
}

