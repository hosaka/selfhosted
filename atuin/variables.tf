variable "db_name" {
  type    = string
  default = "atuin"
}

variable "secrets" {
  type = object({
    db_username = optional(string, "postgres")
    db_password = string
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
    atuin = string
    db    = string
  })
}
