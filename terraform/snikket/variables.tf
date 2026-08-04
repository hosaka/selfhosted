variable "config" {
  type = object({
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

