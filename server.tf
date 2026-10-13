resource "incus_server" "this_per_node" {
  for_each = local.members

  config = {
    "storage.backups_volume" = "local/backups"
    "storage.images_volume"  = "local/images"
    "storage.logs_volume"    = "local/logs"
  }

  depends_on = [
    null_resource.post_projects,
    null_resource.post_networks,
    null_resource.post_storage_pools,
    null_resource.post_storage_volumes,
  ]

  target = each.key
}

resource "incus_server" "this" {
  config = {
  }

  depends_on = [
    null_resource.post_projects,
    null_resource.post_profiles,
    null_resource.post_networks,
    null_resource.post_storage_pools,
    null_resource.post_storage_volumes,
    incus_server.this_per_node,
  ]
}

# IncusOS kernel configuration per member. Incus provider has no resource for this IncusOS API.
# btusb: node-4's MediaTek bluetooth chip has no firmware in IncusOS and retries several times a second.
resource "null_resource" "os_kernel" {
  for_each = local.members

  triggers = {
    target = each.key
    config = jsonencode({
      config = {
        blacklist_modules = ["btusb"]
      }
    })
  }

  provisioner "local-exec" {
    command = "incus query -X PUT --data '${self.triggers.config}' '/os/1.0/system/kernel?target=${self.triggers.target}'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "incus query -X PUT --data '{\"config\": {}}' '/os/1.0/system/kernel?target=${self.triggers.target}'"
  }
}

resource "null_resource" "post_server" {
  depends_on = [
    incus_server.this_per_node,
    incus_server.this,
  ]
}

