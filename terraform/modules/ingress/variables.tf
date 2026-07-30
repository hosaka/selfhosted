variable "config" {
  type = object({
    frp_server_addr    = string
    frp_auth_token     = string
    caddy_cf_api_email = string
    caddy_cf_api_token = string
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

variable "private_domain" {
  type = string
}

