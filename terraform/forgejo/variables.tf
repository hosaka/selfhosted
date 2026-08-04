variable "config" {
  type = object({
    db_name            = optional(string, "forgejo")
    db_username        = optional(string, "postgres")
    db_password        = string
    smtp_address       = string
    smtp_port          = optional(number, 465)
    mailer_from        = string
    mailer_user        = string
    mailer_password    = string
    internal_token     = string
    secret_key         = string
    lfs_jwt_secret     = string
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

