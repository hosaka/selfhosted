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

    uplink = string

    node-1 = object({
      target = optional(string, "node-1")
      nvme-1 = string
      nvme-2 = string
    })
    node-2 = object({
      target = optional(string, "node-2")
      nvme-1 = string
      nvme-2 = string
    })
    node-3 = object({
      target = optional(string, "node-3")
      nvme-1 = string
      nvme-2 = string
    })
    # node-4 = object({
    #   target = optional(string, "node-4")
    #   nvme-1 = string
    #   nvme-2 = string
    # })
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

