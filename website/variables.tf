variable "target" {
  type = string
}

variable "public_domain" {
  type = string
}

# path the site is served under on the public domain, the apex redirects to it
variable "public_prefix" {
  type = string

  validation {
    condition     = can(regex("^/[a-z0-9-]+$", var.public_prefix))
    error_message = "The public prefix must look like /name, without a trailing slash."
  }
}

variable "forgejo_address" {
  description = "Forgejo's internal http address, the builder clones from it directly"
  type        = string
}

variable "repository" {
  description = "The site's Zola project on Forgejo, as owner/name"
  type        = string
}

variable "branch" {
  description = "The branch that gets built and published"
  type        = string
  default     = "main"
}

variable "versions" {
  type = object({
    zola  = string
    caddy = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
