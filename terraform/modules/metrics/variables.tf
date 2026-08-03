variable "config" {
  type = object({
    security_admin_user     = optional(string, "admin")
    security_admin_password = string
    oidc_client_id          = string
    oidc_client_secret      = string
  })
}

variable "target" {
  type = string
}

variable "storage" {
  type    = string
  default = "local"
}

variable "profiles" {
  type = list(string)
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "public_domain" {
  type = string
}

