variable "public_domain" {
  type = string
}

# The VPS running frps, the apex and every name without its own records resolve to it
variable "address" {
  type = string

  validation {
    condition     = can(cidrnetmask("${var.address}/32"))
    error_message = "The address must be an IPv4 address."
  }
}

# The VPS's IPv6 address, names with an A record get an AAAA record next to it
variable "address6" {
  type    = string
  default = null

  validation {
    condition     = var.address6 == null ? true : can(cidrhost("${var.address6}/128", 0)) && strcontains(var.address6, ":")
    error_message = "The address must be an IPv6 address."
  }
}

# Public names that need their own records, collected from the modules' `dns` outputs.
variable "names" {
  type = map(object({
    type  = string
    value = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.names) : r.type == "A" ? r.value == null : contains(["CNAME", "TXT"], r.type) && r.value != null])
    error_message = "Names need either type A without a value, or type CNAME or TXT with one."
  }
}

# Names Caddy gets certificates for, its token may only write their `_acme-challenge` TXT records.
variable "certificates" {
  type    = list(string)
  default = []
}

# Records pointing at external services, set in secrets.auto.tfvars.
variable "records" {
  type = object({
    mx    = list(string)
    txt   = map(list(string)) # do not need to be quoted
    cname = map(string)
  })

  validation {
    condition     = alltrue([for v in concat(var.records.mx, values(var.records.cname)) : endswith(v, ".")])
    error_message = "MX and CNAME targets must be fully qualified, ending with a dot."
  }
}
