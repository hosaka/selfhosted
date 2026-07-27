variable "nodes" {
  type = map(object({
    nic = string
  }))
}
