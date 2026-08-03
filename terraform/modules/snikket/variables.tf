variable "config" {
  type = object({
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

