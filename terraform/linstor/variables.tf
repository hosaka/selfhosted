variable "target" {
  type = string
}

variable "members" {
  type = map(any)
}

variable "timezone" {
  type    = string
  default = "UTC"
}

