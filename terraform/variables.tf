variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

variable "cluster" {
  type = object({
    name = string

    nic1 = string
    nic2 = string

    node-1 = string
    node-2 = string
    node-3 = string
  })
}
