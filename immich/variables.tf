variable "log_level" {
  type    = string
  default = "log"
}

variable "db_name" {
  type    = string
  default = "immich"
}

variable "secrets" {
  type = object({
    db_username = optional(string, "postgres")
    db_password = string
    # unused for now, oauth is configured in the admin settings and stored in the database
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

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

variable "storage_pool" {
  type = string
}

variable "storage_source" {
  type = string
}

variable "cache_pool" {
  type = string
}

variable "versions" {
  type = object({
    immich = string
    db     = string
    cache  = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
