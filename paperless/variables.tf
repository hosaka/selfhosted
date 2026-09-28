variable "config" {
  type = object({
    secret_key         = string
    admin_user         = optional(string, "admin")
    admin_password     = string
    db_name            = optional(string, "paperless")
    db_username        = optional(string, "postgres")
    db_password        = string
    oidc_client_id     = string
    oidc_client_secret = string
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
