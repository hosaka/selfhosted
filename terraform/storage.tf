resource "incus_storage_pool" "local_per_node" {
  for_each = local.members

  name   = "local"
  driver = "zfs"
  target = each.key

  config = {
    "source" = "local/incus"
  }

  lifecycle {
    ignore_changes = [
      # Incus changes the source behind the scenes so we ignore these changes.
      config["source"],
    ]
  }

  depends_on = []
}

resource "incus_storage_pool" "local" {
  name        = "local"
  driver      = "zfs"
  description = "Local storage pool (on system drive)"

  config = {
  }

  depends_on = [
    incus_storage_pool.local_per_node
  ]
}

resource "null_resource" "post_storage_pools" {
  depends_on = [
    incus_storage_pool.local,
  ]
}

