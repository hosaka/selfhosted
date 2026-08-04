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
    name = optional(string, "cluster")

    nic-1  = string
    nic-2  = string
    nvme-1 = string
    nvme-2 = string

    bootstrap = optional(string, "node-1")

    node-1 = optional(object({
      target = optional(string, "node-1")
    }), {})
    node-2 = optional(object({
      target = optional(string, "node-2")
    }), {})
    node-3 = optional(object({
      target = optional(string, "node-3")
    }), {})
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

