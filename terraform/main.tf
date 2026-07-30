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
  storage  = "local"
  profiles = [incus_profile.default.name]

  public_domain  = var.public_domain
  private_domain = var.private_domain
}

module "atuin" {
  source   = "./modules/atuin"
  config   = var.config.atuin
  target   = var.cluster.node-1.target
  storage  = "local"
  profiles = [incus_profile.default.name]

  timezone = var.timezone
}

module "authelia" {
  source   = "./modules/authelia"
  config   = var.config.authelia
  target   = var.cluster.node-1.target
  storage  = "local"
  profiles = [incus_profile.default.name]

  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
}

module "notify" {
  source   = "./modules/notify"
  config   = var.config.notify
  target   = var.cluster.node-1.target
  storage  = "local"
  profiles = [incus_profile.default.name]

  public_domain = var.public_domain
  timezone      = var.timezone
}
