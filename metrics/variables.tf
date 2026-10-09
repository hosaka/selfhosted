variable "port" {
  type    = string
  default = "8444"
}

variable "secrets" {
  type = object({
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

variable "versions" {
  type = object({
    grafana    = string
    prometheus = string
    loki       = string
  })
}
