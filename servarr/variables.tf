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

# The reverse proxy whose X-Forwarded-For header the apps trust
variable "proxy_address" {
  type = string
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
