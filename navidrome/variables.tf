variable "secrets" {
  type = object({
    lastfm_apikey = string
    lastfm_secret = string
  })
}

variable "target" {
  type = string
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
    navidrome = string
  })
}
