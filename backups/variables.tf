variable "secrets" {
  type = object({
    username            = string
    password_bcrypt     = string # base64 of a bcrypt hash
    restic_password_nas = string
  })
}

variable "target" {
  type = string
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "private_domain" {
  type = string
}

# Pool of the `nas` restic repository volume
variable "restic_pool" {
  type = string
}

# Incus API the hooks talk to, as https://<address>:<port>
variable "cluster_address" {
  type = string
}

# The cluster's server certificate, pinned by the hooks' Incus client
variable "cluster_certificate" {
  type = string
}

# What to back up, from each module's `backups` output
variable "sources" {
  type = list(object({
    volumes = optional(map(object({         # LINSTOR volumes, cloned from a snapshot and mounted read-only
      excludes = optional(list(string), []) # paths are relative to the volume
    })), {})
    databases = optional(list(string), []) # Postgres instances, dumped with pg_dumpall
  }))
}

variable "versions" {
  type = object({
    backrest     = string
    incus        = string
    incus_sha256 = string
  })
}
