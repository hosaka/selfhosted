variable "config" {
  type    = object({})
  default = {}
}

variable "target" {
  type = string
}

variable "timezone" {
  type    = string
  default = "UTC"
}

