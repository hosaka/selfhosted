# Every service is optional, its widgets show up in Glance if configured.
# Some widgets require an API key (see glance.tf/local.known_services)
variable "services" {
  type = map(object({
    address = string
    api_key = optional(string)
  }))
  default = {}
}

variable "storage" {
  description = "Settings of the Storage widget"
  type = object({
    # unique storage sources which can be counted for total/used/free space
    sources = optional(list(string), [])
  })
  default = {}
}

variable "backups" {
  description = "Settings of the Backups widget"
  type = object({
    # restic repository the widget shows, it's hidden without one
    repository = optional(string)
    # cron schedule of the repository's backups, helps determine when is the "Next Backup"
    schedule = optional(string)
  })
  default = {}

  validation {
    condition     = var.backups.schedule == null || can(regex("^[0-9]+ [0-9]+ \\* \\* \\*$", var.backups.schedule))
    error_message = "Only daily schedules (\"M H * * *\") are supported."
  }
}

variable "forward_auth" {
  description = "Address of the forward auth server put in front of Glance"
  type        = string
}

variable "target" {
  type = string
}

variable "timezone" {
  type = string
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

variable "versions" {
  type = object({
    glance = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
