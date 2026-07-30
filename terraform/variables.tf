variable "cluster" {
  type = object({
    name = string

    nic-1  = string
    nic-2  = string
    nvme-1 = string
    nvme-2 = string

    node-1 = object({
      target = string
    })
    node-2 = object({
      target = string
    })
    node-3 = object({
      target = string
    })
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

# Shared
variable "timezone" {
  type = string
}

variable "public_domain" {
  type = string
}

variable "private_domain" {
  type = string
}

# FRP
variable "frp_server_addr" {
  type = string
}

variable "frp_auth_token" {
  type      = string
  sensitive = true
}

# Caddy
variable "caddy_cf_api_email" {
  type      = string
  sensitive = true
}

variable "caddy_cf_api_token" {
  type      = string
  sensitive = true
}

# Atuin
variable "atuin_db_name" {
  type    = string
  default = "atuin"
}

variable "atuin_db_username" {
  type    = string
  default = "postgres"
}

variable "atuin_db_password" {
  type      = string
  sensitive = true
}

# Diun
variable "diun_gotify_token" {
  type      = string
  sensitive = true
}

variable "diun_dockerhub_username" {
  type = string
}

variable "diun_dockerhub_password" {
  type      = string
  sensitive = true
}

variable "diun_ghcr_username" {
  type = string
}

variable "diun_ghcr_password" {
  type      = string
  sensitive = true
}

# Authelia
variable "auth_gotify_client_id" {
  type = string
}

variable "auth_gotify_client_secret" {
  type      = string
  sensitive = true
}

variable "auth_gotify_client_secret_hash" {
  type = string
}
