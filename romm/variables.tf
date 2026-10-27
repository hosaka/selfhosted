variable "db_name" {
  type    = string
  default = "romm"
}

variable "trusted_proxies" {
  type    = list(string)
  default = ["10.0.0.0/8"]
}

variable "secrets" {
  type = object({
    auth_secret_key        = string
    db_username            = optional(string, "postgres")
    db_password            = string
    oidc_client_id         = string
    oidc_client_secret     = string
    igdb_client_id         = string
    igdb_client_secret     = string
    steamgriddb_api_key    = string
    screenscraper_user     = string
    screenscraper_password = string
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

variable "public_domain" {
  type = string
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

variable "cache_pool" {
  type = string
}

variable "versions" {
  type = object({
    romm = string
    db   = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
