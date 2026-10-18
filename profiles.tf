resource "incus_profile" "default" {
  name        = "default"
  description = "Default Incus profile"

  config = {
    # "limits.cpu" = "1"
    # "limits.memory" = "512MiB"

    # Incus starts instances without a priority first, all at once, and only then the others by priority.
    # With a priority on every instance they all start one by one: infrastructure (100), datastores (50), the rest (0).
    "boot.autostart.priority" = 0
  }

  # instances get an address from OVN's DHCP range, services replace eth0 with a fixed one
  device {
    name = "eth0"
    type = "nic"
    properties = {
      "network" = module.ovn.network
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

resource "incus_profile" "internal_default" {
  name        = "default"
  description = "Default cluster internal profile"

  project = "internal"

  config = {
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

# containers with a static address skip DHCP and get their DNS servers from here
resource "incus_profile" "oci" {
  name        = "oci"
  description = "DNS for OCI containers"

  config = {
    "oci.dns.nameservers" = split("/", var.cluster.gateway)[0]
    # bare instance names resolve through OVN DNS records, <name>.incus
    "oci.dns.search" = "incus"
  }

  depends_on = [
    null_resource.post_projects,
  ]
}

# Databases, caches and directories that apps connect to on startup.
# The instance will start before the app and stop after it.
resource "incus_profile" "datastore" {
  name        = "datastore"
  description = "Boot order for databases and caches"

  config = {
    "boot.autostart.priority" = 50
    "boot.stop.priority"      = -50
  }

  depends_on = [
    null_resource.post_projects,
  ]
}

resource "null_resource" "post_profiles" {
  depends_on = [
    incus_profile.default,
    incus_profile.oci,
    incus_profile.datastore,
    incus_profile.internal_default,
  ]
}
