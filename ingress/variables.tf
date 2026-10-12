
variable "secrets" {
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
    frpc  = string
    caddy = string
  })
}

variable "services" {
  type = list(object({
    name       = string
    caddy      = optional(string, "")
    caddy_apex = optional(string, "")
    frpc       = optional(string, "")
  }))
  default = []
}
