resource "incus_storage_volume" "backups" {
  for_each = local.members

  name         = "backups"
  description  = "Volume holding system backups"
  target       = each.key
  pool         = "local"
  type         = "custom"
  content_type = "filesystem"

  config = {
  }

  depends_on = [
    null_resource.post_storage_pools,
    null_resource.post_projects,
  ]
}

resource "incus_storage_volume" "images" {
  for_each = local.members

  name         = "images"
  description  = "Volume holding system images"
  target       = each.key
  pool         = "local"
  type         = "custom"
  content_type = "filesystem"

  config = {
  }

  depends_on = [
    null_resource.post_storage_pools,
    null_resource.post_projects,
  ]
}

resource "incus_storage_volume" "logs" {
  for_each = local.members

  name         = "logs"
  description  = "Volume holding system logs"
  target       = each.key
  pool         = "local"
  type         = "custom"
  content_type = "filesystem"

  config = {
  }

  depends_on = [
    null_resource.post_storage_pools,
    null_resource.post_projects,
  ]
}

# resource "incus_storage_volume" "media" {
#   name         = "media"
#   description  = "Shared media library"
#   target       = "node-4"
#   pool         = incus_storage_pool.nas.name
#   type         = "custom"
#   content_type = "filesystem"
#
#   config = {
#     "security.shifted" = "true"
#   }
#
#   depends_on = [
#     null_resource.post_storage_pools,
#   ]
# }

# resource "incus_storage_volume" "immich" {
#   name         = "immich"
#   description  = "Immich photo and video library"
#   target       = "node-4"
#   pool         = incus_storage_pool.nas.name
#   type         = "custom"
#   content_type = "filesystem"
#
#   depends_on = [
#     null_resource.post_storage_pools,
#   ]
# }

# resource "incus_storage_volume" "voidrepo" {
#   name         = "voidrepo"
#   description  = "Void Linux repository mirror"
#   target       = "node-4"
#   pool         = incus_storage_pool.nas.name
#   type         = "custom"
#   content_type = "filesystem"
#
#   config = {
#     # shared between voidrepo-sync and voidrepo
#     "security.shifted" = "true"
#   }
#
#   depends_on = [
#     null_resource.post_storage_pools,
#   ]
# }

resource "null_resource" "post_storage_volumes" {
  depends_on = [
    incus_storage_volume.backups,
    incus_storage_volume.images,
    incus_storage_volume.logs,
    # incus_storage_volume.immich,
    # incus_storage_volume.media,
    # incus_storage_volume.voidrepo,
  ]
}

