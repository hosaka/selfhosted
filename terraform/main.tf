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
  source   = "./modules/ingress"
  config   = var.config.ingress
  target   = var.cluster.node-1.target
  storage  = incus_storage_pool.remote.name
  profiles = [incus_profile.default.name, incus_profile.replicated.name]

  public_domain  = var.public_domain
  private_domain = var.private_domain
}

module "atuin" {
  source   = "./modules/atuin"
  config   = var.config.atuin
  target   = var.cluster.node-1.target
  storage  = incus_storage_pool.remote.name
  profiles = [incus_profile.default.name, incus_profile.replicated.name]
  timezone = var.timezone
}

# todo: configure lldap user and set the password
module "auth" {
  source         = "./modules/auth"
  config         = var.config.auth
  target         = var.cluster.node-1.target
  storage        = incus_storage_pool.remote.name
  profiles       = [incus_profile.default.name, incus_profile.replicated.name]
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
}

module "homeassistant" {
  source   = "./modules/homeassistant"
  config   = var.config.homeassistant
  target   = var.cluster.node-1.target
  storage  = incus_storage_pool.remote.name
  profiles = [incus_profile.default.name, incus_profile.replicated.name]
  timezone = var.timezone
}

module "notify" {
  source        = "./modules/notify"
  config        = var.config.notify
  target        = var.cluster.node-1.target
  storage       = incus_storage_pool.remote.name
  profiles      = [incus_profile.default.name, incus_profile.replicated.name]
  public_domain = var.public_domain
  timezone      = var.timezone
}

module "searxng" {
  source        = "./modules/searxng"
  config        = var.config.searxng
  target        = var.cluster.node-1.target
  storage       = incus_storage_pool.remote.name
  profiles      = [incus_profile.default.name, incus_profile.replicated.name]
  public_domain = var.public_domain
  timezone      = var.timezone
}

module "slskd" {
  source        = "./modules/slskd"
  config        = var.config.slskd
  target        = var.cluster.node-1.target
  storage       = incus_storage_pool.remote.name
  profiles      = [incus_profile.default.name, incus_profile.replicated.name]
  public_domain = var.public_domain
  timezone      = var.timezone
}

module "syncstorage" {
  source        = "./modules/syncstorage"
  config        = var.config.syncstorage
  target        = var.cluster.node-1.target
  storage       = incus_storage_pool.remote.name
  profiles      = [incus_profile.default.name, incus_profile.replicated.name]
  public_domain = var.public_domain
  timezone      = var.timezone
}

module "vault" {
  source        = "./modules/vault"
  config        = var.config.vault
  target        = var.cluster.node-1.target
  storage       = incus_storage_pool.remote.name
  profiles      = [incus_profile.default.name, incus_profile.replicated.name]
  public_domain = var.public_domain
  timezone      = var.timezone
}

module "wakapi" {
  source        = "./modules/wakapi"
  config        = var.config.wakapi
  target        = var.cluster.node-1.target
  storage       = incus_storage_pool.remote.name
  profiles      = [incus_profile.default.name, incus_profile.replicated.name]
  public_domain = var.public_domain
  timezone      = var.timezone
}
