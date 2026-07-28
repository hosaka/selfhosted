variable "wakapi_version" {
  type    = string
  default = "2.17.4"
}

resource "incus_storage_volume" "wakapi_data" {
  name = "wakapi_data"
  pool = incus_storage_pool.remote.name
}

resource "incus_instance" "wakapi" {
  depends_on = [incus_storage_volume.wakapi_data]

  name     = "wakapi"
  type     = "container"
  profiles = [incus_profile.default.name]
  image    = "ghcr:muety/wakapi:${var.wakapi_version}"

  device {
    name = "wakapi_data"
    type = "disk"
    properties = {
      # todo: attempting to mount on /data fails in OCI because it doesn't exist
      # wakapi does provide an env var to control the DB placement, but the data dir
      # also containes the config.yml, need to investigate further
      path   = "/tmp/data"
      pool   = incus_storage_pool.remote.name
      source = incus_storage_volume.wakapi_data.name
    }
  }
}

