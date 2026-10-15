variable "port" {
  type    = string
  default = "8444"
}

variable "secrets" {
  type = object({
    oidc_client_id     = string
    oidc_client_secret = string
    frps_user          = string
    frps_password      = string
    gotify_token       = string # of the Grafana application
  })
}

variable "members" {
  type = map(any)
}

variable "target" {
  type = string
}

variable "snapshots" {
  type    = map(string)
  default = {}
}

variable "timezone" {
  type    = string
  default = "UTC"
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

variable "versions" {
  type = object({
    alloy             = string
    blackbox_exporter = string
    grafana           = string
    loki              = string
    prometheus        = string
    smartctl_exporter = string
  })
}

# Drives to monitor per cluster member, as /dev/disk/by-id paths.
variable "smart_devices" {
  type    = map(list(string))
  default = {}
}

# The LINSTOR controller, which serves its Prometheus metrics on /metrics.
variable "linstor_address" {
  type = string
}

# Members running an Alloy that ships their console output to Loki.
variable "log_collectors" {
  type    = set(string)
  default = []
}

# Caddy's metrics endpoint, as <address>:<port>.
variable "caddy_address" {
  type = string
}

# The frps dashboard, as <address>:<port>.
variable "frps_address" {
  type = string
}

# Authelia's metrics, as <address>:<port>.
variable "authelia_address" {
  type = string
}

# Immich's api and job worker metrics, as <address>:<port> by worker.
variable "immich_addresses" {
  type = map(string)
}

# restic-exporter's metrics, as <address>:<port> by restic repository.
variable "restic_exporter_addresses" {
  type    = map(string)
  default = {}
}

# Gotify the alert notifications go to, as http://<address>:<port>
variable "gotify_address" {
  type = string
}

# Health check URLs the blackbox exporter probes, by the module that serves them.
variable "probes" {
  type    = map(list(string))
  default = {}
}
