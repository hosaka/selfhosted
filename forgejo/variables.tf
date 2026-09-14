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
    trusted_proxies    = optional(string, "127.0.0.0/8,::1/128,10.0.0.0/8")
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

variable "private_domain" {
  type = string
}

