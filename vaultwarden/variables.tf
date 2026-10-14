variable "smtp_from" {
  type    = string
  default = null
}

variable "smtp_port" {
  type    = number
  default = 465
}

variable "smtp_security" {
  type    = string
  default = "force_tls"
}

variable "secrets" {
  type = object({
    admin_token        = string
    smtp_host          = string
    smtp_password      = string
    smtp_username      = string
    oidc_client_id     = string
    oidc_client_secret = string
    yubico_client_id   = string
    yubico_secret_key  = string
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
    vaultwarden = string
  })
}
