variable "config" {
  type = object({
    password_salt      = string
    oidc_client_id     = string
    oidc_client_secret = string
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

