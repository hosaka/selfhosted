variable "admin_group" {
  type    = string
  default = "opencloud_admin"
}

variable "user_group" {
  type    = string
  default = "opencloud_user"
}

variable "smtp_sender" {
  type    = string
  default = null
}

variable "smtp_port" {
  type    = number
  default = 465
}

variable "smtp_encryption" {
  type    = string
  default = "ssltls" # starttls, ssltls or none
}

variable "secrets" {
  type = object({
    smtp_host           = string
    smtp_username       = string
    smtp_password       = string
    oidc_client_id      = string
    oidc_apps_client_id = string
  })
}

variable "target" {
  type = string
}

variable "snapshots" {
  type    = map(string)
  default = {}
}

variable "public_domain" {
  type = string
}

variable "storage_pool" {
  type = string
}

variable "storage_source" {
  type = string
}

variable "versions" {
  type = object({
    opencloud = string
  })
}

# Fixed OVN address and NIC per instance, see addresses.auto.tfvars
variable "addresses" {
  type = map(object({
    ipv4 = string
    nic  = map(string)
  }))
}
