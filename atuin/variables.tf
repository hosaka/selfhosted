variable "config" {
  type = object({
    db_name     = optional(string, "atuin")
    db_username = optional(string, "postgres")
    db_password = string
  })
}

variable "target" {
  type = string
}

variable "timezone" {
  type    = string
  default = "UTC"
}

