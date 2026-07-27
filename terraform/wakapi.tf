variable "wakapi_version" {
  type = string
  default = "2.17.4"
}

resource "incus_storage_volume" "wakapi-data" {
  name = "wakapi-data"
  pool = "local"
  target = "incus-1"
}

resource "incus_instance" "wakapi" {
  name     = "wakapi"
  type     = "container"
  image    = "ghcr:muety/wakapi:${var.wakapi_version}"
  target = "incus-1"
  profiles = ["default"]

  config = {
    "environment.TZ" = "Asia/Tokyo"
  }

  device {
    name = "wakapi-data"
    type = "disk"
    properties = {
      # attempting to mount on /data fails in OCI because it doesn't exist
      # wakapi does provide an env var to control the DB placement, but the data dir
      # also containes the config.yml, need to investigate further
      path = "/tmp/data"
      pool = "local"
      source = incus_storage_volume.wakapi-data.name
    }
  }
}

