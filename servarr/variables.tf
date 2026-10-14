variable "secrets" {
  type = object({
    lidarr_api_key   = string
    prowlarr_api_key = string
    radarr_api_key   = string
    sonarr_api_key   = string
  })
}

variable "target" {
  type = string
}

variable "snapshots" {
  type    = map(string)
  default = {}
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "private_domain" {
  type = string
}

variable "media_pool" {
  type = string
}

variable "media_source" {
  type = string
}

variable "versions" {
  type = object({
    lidarr    = string
    prowlarr  = string
    radarr    = string
    recyclarr = string
    seerr     = string
    sonarr    = string
  })
}
