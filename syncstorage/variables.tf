variable "db_name" {
  type    = string
  default = "syncserver"
}

variable "secrets" {
  type = object({
    master_secret       = string
    db_username         = optional(string, "postgres")
    db_password         = string
    metrics_hash_secret = string
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

variable "versions" {
  type = object({
    syncstorage = string
    db          = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
