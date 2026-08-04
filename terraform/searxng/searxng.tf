variable "searxng_version" {
  type    = string
  default = "2026.7.31-057a77168"
}

resource "incus_instance" "searxng" {
  name = "searxng"

  target   = var.target
  profiles = ["default"]
  image    = "ghcr:searxng/searxng:${var.searxng_version}"

  file {
    content            = file("${path.module}/settings.yml")
    target_path        = "/etc/searxng/settings.yml"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = file("${path.module}/limiter.toml")
    target_path        = "/etc/searxng/limiter.toml"
    mode               = "0600"
    create_directories = true
  }

  config = {
    "environment.SEARXNG_SECRET"    = sensitive(var.config.secret)
    "environment.SEARXNG_BASE_URL"  = "https://search.${var.public_domain}"
    "environment.SEARXNG_REDIS_URL" = "redis://searxng-valkey:6379"
  }
}

resource "incus_storage_volume" "searxng_cache" {
  name   = "searxng-cache"
  pool   = "local"
  target = var.target
}

resource "incus_instance" "searxng_valkey" {
  name = "searxng-valkey"
  type = "container"

  target   = var.target
  profiles = ["default"]
  image    = "docker:valkey/valkey:8-alpine"

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = "/data"
      pool   = incus_storage_volume.searxng_cache.pool
      source = incus_storage_volume.searxng_cache.name
    }
  }
}
