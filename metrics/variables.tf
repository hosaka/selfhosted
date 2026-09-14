variable "config" {
  type = object({
    port               = optional(string, "8444")
    oidc_client_id     = string
    oidc_client_secret = string
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

