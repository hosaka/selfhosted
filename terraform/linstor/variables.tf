variable "config" {
  type = object({
    members = map(any)
  })
}

variable "target" {
  type = string
}

variable "timezone" {
  type    = string
  default = "UTC"
}

