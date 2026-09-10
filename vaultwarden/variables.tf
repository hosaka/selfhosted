variable "config" {
  type = object({
    admin_token        = string
    smtp_from          = string
    smtp_host          = string
    smtp_password      = string
    smtp_port          = optional(number, 465)
    smtp_security      = optional(string, "force_tls")
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

