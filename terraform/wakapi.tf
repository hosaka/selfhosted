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
  profiles = ["default", incus_profile.base.name]

  config = {
    "environment.TZ" = "Asia/Tokyo"
  }

  device {
    name = "wakapi-data"
    type = "disk"
    properties = {
      path = "/data"
      pool = "local"
      source = incus_storage_volume.wakapi-data.name
    }
  }
}

