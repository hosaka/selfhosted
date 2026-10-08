variable "target" {
  type = string
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

variable "storage_pool" {
  type = string
}

variable "storage_source" {
  type = string
}

variable "cron_schedule" {
  description = "When to sync the mirror, at minute 0 past every 3rd hour by default"
  type        = string
  default     = "0 */3 * * *"
}

variable "rsync_args" {
  description = "Additional rsync arguments, e.g. --dry-run when testing"
  type        = string
  default     = ""
}
