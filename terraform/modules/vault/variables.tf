variable "config" {
  type = object({
    admin_token        = string
    smtp_from          = string
    smtp_host          = string
    smtp_password      = string
    smtp_port          = number
    smtp_security      = string
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

