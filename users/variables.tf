variable "secrets" {
  type = object({
    authelia_password = string
  })
}

variable "public_domain" {
  type = string
}

# People with an account, by username.
variable "users" {
  type = map(object({
    email        = string
    display_name = optional(string, "")
    first_name   = optional(string, "")
    last_name    = optional(string, "")
    groups       = optional(set(string), [])
  }))
  default = {}
}
