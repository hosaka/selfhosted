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
  })
}
