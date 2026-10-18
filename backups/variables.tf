variable "secrets" {
  type = object({
    backrest_username        = string
    backrest_password_bcrypt = string # base64 of a bcrypt hash
    restic_password          = string
    gotify_token             = string # of the Backrest application
    s3_repository            = string # restic's s3:https://<endpoint>/<bucket> uri
    s3_access_key_id         = string
    s3_secret_access_key     = string
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

# Gotify the failure notifications go to, as http://<address>:<port>
variable "gotify_address" {
  type = string
}

# What to back up per application. These go to nas and an s3 repo.
variable "sources" {
  type = map(object({
    volumes = optional(map(object({         # LINSTOR volumes, cloned from a snapshot and mounted read-only
      excludes = optional(list(string), []) # paths are relative to the volume
    })), {})
    databases = optional(list(string), []) # Postgres instances, dumped with pg_dumpall
  }))
}

# Volumes on the nas pool, by plan name. They go to the s3 repo only.
variable "nas_sources" {
  type = map(object({
    pool     = string
    volume   = string
    paths    = optional(list(string), [""]) # relative to the volume, all included by default
    excludes = optional(list(string), [])   # relative to the volume
  }))
  default = {}
}

variable "versions" {
  type = object({
    backrest        = string
    incus           = string
    incus_sha256    = string
    restic_exporter = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
