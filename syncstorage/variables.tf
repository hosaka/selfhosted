variable "config" {
  type = object({
    master_secret       = string
    db_name             = optional(string, "syncserver")
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

