variable "config" {
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
