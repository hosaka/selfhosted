# locals {
#   nas_sources = {
#     for m in keys(local.members) : m => (m == "node-4" ? "nas/incus" : "local/nas")
#   }
# }
#
# resource "incus_storage_pool" "nas_per_node" {
#   for_each = local.nas_sources
#
#   name   = "nas"
#   driver = "zfs"
#   target = each.key
#
#   config = {
#     "source" = each.value
#   }
#
#   lifecycle {
#     ignore_changes = [
#       config["source"],
#     ]
#   }
# }
#
# resource "incus_storage_pool" "nas" {
#   name        = "nas"
#   driver      = "zfs"
#   description = "NAS storage pool (raidz1 on HDDs)"
#
#   config = {
#   }
#
#   depends_on = [
#     incus_storage_pool.nas_per_node
#   ]
# }

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
    # incus_storage_pool.nas
  ]
}

