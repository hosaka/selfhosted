variable "secrets" {
  type = object({
    # unused for now, the SSO plugin keeps its own copy in /config
    # but let's hope that Jellyfin gets native OIDC support one day
    oidc_client_secret = string
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
    jellyfin = string
  })
}
