data "incus_cluster" "this" {
  remote = var.cluster.name
  lifecycle {
    postcondition {
      condition     = alltrue(self.is_clustered ? [for i, v in self.members : v.status == "Online"] : [])
      error_message = "All servers must be online."
    }
  }
}

# This is the entrypoint for all server traffic.
module "ingress" {
  source         = "./ingress"
  config         = var.config.ingress
  target         = var.cluster.node-3.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
}

module "atuin" {
  source   = "./atuin"
  config   = var.config.atuin
  target   = var.cluster.node-1.target
  timezone = var.timezone
}

# todo: configure lldap user and set the password
module "auth" {
  source         = "./auth"
  config         = var.config.auth
  target         = var.cluster.node-1.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
}

module "homeassistant" {
  source   = "./homeassistant"
  config   = var.config.homeassistant
  target   = var.cluster.node-1.target
  timezone = var.timezone
}

module "metrics" {
  source        = "./metrics"
  config        = var.config.metrics
  target        = var.cluster.node-2.target
  public_domain = var.public_domain
  timezone      = var.timezone
}

module "notify" {
  source        = "./notify"
  config        = var.config.notify
  target        = var.cluster.node-2.target
  public_domain = var.public_domain
  timezone      = var.timezone
}

module "searxng" {
  source        = "./searxng"
  config        = var.config.searxng
  target        = var.cluster.node-3.target
  public_domain = var.public_domain
  timezone      = var.timezone
}

module "slskd" {
  source        = "./slskd"
  config        = var.config.slskd
  target        = var.cluster.node-1.target
  public_domain = var.public_domain
  timezone      = var.timezone
}

# module "snikket" {
#   source        = "./snikket"
#   config        = var.config.snikket
#   target        = var.cluster.node-3.target
#   public_domain = var.public_domain
#   timezone      = var.timezone
# }

module "syncstorage" {
  source        = "./syncstorage"
  config        = var.config.syncstorage
  target        = var.cluster.node-1.target
  public_domain = var.public_domain
  timezone      = var.timezone
}

module "vaultwarden" {
  source        = "./vaultwarden"
  config        = var.config.vaultwarden
  target        = var.cluster.node-1.target
  public_domain = var.public_domain
  timezone      = var.timezone
}

module "wakapi" {
  source        = "./wakapi"
  config        = var.config.wakapi
  target        = var.cluster.node-2.target
  public_domain = var.public_domain
  timezone      = var.timezone
}
