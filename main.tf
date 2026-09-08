data "incus_cluster" "this" {
  remote = var.cluster.name
  lifecycle {
    postcondition {
      condition     = alltrue(self.is_clustered ? [for i, v in self.members : v.status == "Online"] : [])
      error_message = "All cluster members must be online."
    }
  }
}

locals {
  members = data.incus_cluster.this.is_clustered ? { for k, v in data.incus_cluster.this.members : k => v } : {}
}

# Replicated storage
module "linstor" {
  source     = "./linstor"
  target     = var.cluster.node-1.target
  members    = local.members
  depends_on = [null_resource.post_server]
}

# This is the entrypoint for all server traffic.
module "ingress" {
  source = "./ingress"

  config         = var.config.ingress
  target         = var.cluster.node-3.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]

  services = [
    module.atuin.ingress,
    module.notify.ingress,
    module.whoami.ingress,
  ]
}

# # Service authentication layer
# module "auth" {
#   source         = "./auth"
#   config         = var.config.auth
#   target         = var.cluster.node-3.target
#   public_domain  = var.public_domain
#   private_domain = var.private_domain
#   timezone       = var.timezone
#   depends_on     = [null_resource.post_server, module.linstor]
# }

module "atuin" {
  source         = "./atuin"
  config         = var.config.atuin
  target         = var.cluster.node-1.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

# module "forgejo" {
#   source        = "./forgejo"
#   config        = var.config.forgejo
#   target        = var.cluster.node-2.target
#   public_domain = var.public_domain
#   timezone      = var.timezone
#   depends_on    = [null_resource.post_server, module.linstor]
# }

# module "homeassistant" {
#   source     = "./homeassistant"
#   config     = var.config.homeassistant
#   target     = var.cluster.node-1.target
#   timezone   = var.timezone
#   depends_on = [null_resource.post_server, module.linstor]
# }

# module "metrics" {
#   source        = "./metrics"
#   config        = var.config.metrics
#   members       = local.members
#   target        = var.cluster.node-2.target
#   public_domain = var.public_domain
#   timezone      = var.timezone
#   depends_on    = [null_resource.post_server, module.linstor]
# }

module "notify" {
  source         = "./notify"
  config         = var.config.notify
  target         = var.cluster.node-2.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

# module "searxng" {
#   source        = "./searxng"
#   config        = var.config.searxng
#   target        = var.cluster.node-3.target
#   public_domain = var.public_domain
#   timezone      = var.timezone
#   depends_on    = [null_resource.post_server, module.linstor]
# }

# module "slskd" {
#   source        = "./slskd"
#   config        = var.config.slskd
#   target        = var.cluster.node-1.target
#   public_domain = var.public_domain
#   timezone      = var.timezone
#   depends_on    = [null_resource.post_server, module.linstor]
# }

# module "snikket" {
#   source        = "./snikket"
#   config        = var.config.snikket
#   target        = var.cluster.node-3.target
#   public_domain = var.public_domain
#   timezone      = var.timezone
#   depends_on    = [null_resource.post_server, module.linstor]
# }

# module "syncstorage" {
#   source        = "./syncstorage"
#   config        = var.config.syncstorage
#   target        = var.cluster.node-1.target
#   public_domain = var.public_domain
#   timezone      = var.timezone
#   depends_on    = [null_resource.post_server, module.linstor]
# }

# module "vaultwarden" {
#   source        = "./vaultwarden"
#   config        = var.config.vaultwarden
#   target        = var.cluster.node-1.target
#   public_domain = var.public_domain
#   timezone      = var.timezone
#   depends_on    = [null_resource.post_server, module.linstor]
# }

# module "wakapi" {
#   source        = "./wakapi"
#   config        = var.config.wakapi
#   target        = var.cluster.node-2.target
#   public_domain = var.public_domain
#   timezone      = var.timezone
#   depends_on    = [null_resource.post_server, module.linstor]
# }

module "whoami" {
  source         = "./whoami"
  target         = var.cluster.node-1.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  depends_on     = [null_resource.post_server]
}
