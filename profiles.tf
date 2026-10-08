resource "incus_profile" "default" {
  name        = "default"
  description = "Default Incus profile"

  config = {
    # "limits.cpu" = "1"
    # "limits.memory" = "512MiB"
    # "snapshots.schedule" = "@daily"
    # "snapshots.expiry"   = "7d"
    # "environment.TZ" = var.timezone
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      "network" = "incusbr0"
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      "path" = "/"
      "pool" = "local"
    }
  }

  depends_on = [
    null_resource.post_storage_pools,
    null_resource.post_projects,
    null_resource.post_networks,
  ]
}

resource "incus_profile" "mesh" {
  name        = "mesh"
  description = "Second NIC on meshbr0, mesh subnet only (no default route)"

  device {
    name = "eth1"
    type = "nic"
    properties = {
      # name is required for ipv4.gateway to appl
      name           = "eth1"
      network        = "meshbr0"
      "ipv4.gateway" = "none"
    }
  }

  depends_on = [
    null_resource.post_projects,
    null_resource.post_networks,
  ]
}

resource "incus_profile" "internal_default" {
  name        = "default"
  description = "Default cluster internal profile"

  project = "internal"

  config = {
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      "network" = "meshbr0"
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      "path" = "/"
      "pool" = "local"
    }
  }

  depends_on = [
    null_resource.post_storage_pools,
    null_resource.post_projects,
    null_resource.post_networks,
  ]
}

resource "null_resource" "post_profiles" {
  depends_on = [
    incus_profile.default,
    incus_profile.mesh,
    incus_profile.internal_default,
  ]
}
