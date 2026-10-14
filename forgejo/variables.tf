variable "db_name" {
  type    = string
  default = "forgejo"
}

variable "smtp_port" {
  type    = number
  default = 465
}

variable "mailer_from" {
  type    = string
  default = null
}

variable "trusted_proxies" {
  type    = string
  default = "127.0.0.0/8,::1/128,10.0.0.0/8"
}

variable "secrets" {
  type = object({
    smtp_address       = string
    db_username        = optional(string, "postgres")
    db_password        = string
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
    anubis  = string
    forgejo = string
    db      = string
  })
}
