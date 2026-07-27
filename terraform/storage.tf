resource "incus_server" "linstor_controller" {
  config = {
    "storage.linstor.controller_connection" = "http://10.10.0.28:3370"
  }
}

resource "incus_storage_pool" "remote_pending" {
  for_each = var.nodes
  name     = "remote"
  driver   = "linstor"
  target   = each.key

  depends_on = [incus_server.linstor_controller]
}

resource "incus_storage_pool" "remote" {
  name   = "remote"
  driver = "linstor"
  description = "Remote storage pool (LINSTOR)"

  config = {
    "linstor.resource_group.name" = "remote"
    "linstor.resource_group.storage_pool" = "nvme_pool"
    "linstor.resource_group.place_count"  = "2"
  }

  depends_on = [incus_storage_pool.remote_pending]
}
