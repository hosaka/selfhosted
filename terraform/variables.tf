variable "timezone" {
  type = string
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

# Single object holding all configs for services.
variable "config" {
  type = map(any)
}

variable "cluster" {
  type = object({
    name = string

    nic-1  = string
    nic-2  = string
    nvme-1 = string
    nvme-2 = string

    node-1 = object({
      target = string
    })
    node-2 = object({
      target = string
    })
    node-3 = object({
      target = string
    })
  })
}

variable "services" {
  type = object({
    gateway = string

    linstor = object({
      ipv4 = string
    })
  })
}

