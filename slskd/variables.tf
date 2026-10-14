variable "puid" {
  type    = string
  default = "1000"
}

variable "pgid" {
  type    = string
  default = "1000"
}

variable "umask" {
  type    = string
  default = "002"
}

variable "secrets" {
  type = object({
    slsk_username       = string
    slsk_password       = string
    slsk_proxy_username = string
    slsk_proxy_password = string
  })
}

variable "target" {
  type = string
}

variable "snapshots" {
  type    = map(string)
  default = {}
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

variable "media_pool" {
  type = string
}

variable "media_source" {
  type = string
}

variable "versions" {
  type = object({
    slskd = string
  })
}
