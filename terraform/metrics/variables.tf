variable "config" {
  type = object({
    security_admin_user     = optional(string, "admin")
    security_admin_password = string
    oidc_client_id          = string
    oidc_client_secret      = string
  })
}

variable "members" {
  type = map(any)
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

variable "metrics_port" {
  type    = string
  default = "8444"
}

