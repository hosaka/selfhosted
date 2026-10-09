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

  # Members the cluster-wide pools and networks were created with.
  # Their per-member config can only be defined before a pool or network exists,
  # members joining later get it from the `incus cluster join` prompts.
  founding_members = {
    for k, v in local.members : k => v
    if contains([var.cluster.node-1.target, var.cluster.node-2.target, var.cluster.node-3.target], k)
  }
}

# Replicated storage
module "linstor" {
  source = "./linstor"
  target = var.cluster.node-1.target
  # Satellites and the pool's per-member config are bootstrap-time only,
  # members joining later are registered and configured during the join
  members    = local.founding_members
  depends_on = [null_resource.post_server]
}

# This is the entrypoint for all server traffic.
module "ingress" {
  source         = "./ingress"
  versions       = var.versions.ingress
  secrets        = var.secrets.ingress
  target         = var.cluster.node-3.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]

  services = [
    module.auth.ingress,
    module.atuin.ingress,
    module.forgejo.ingress,
    # module.homeassistant.ingress,
    # module.immich.ingress,
    # module.jellyfin.ingress,
    # module.kavita.ingress,
    module.metrics.ingress,
    # module.navidrome.ingress,
    module.notify.ingress,
    module.paperless.ingress,
    # module.qbittorrent.ingress,
    # module.sabnzbd.ingress,
    # module.searxng.ingress,
    # module.servarr.ingress,
    # module.slskd.ingress,
    module.snikket.ingress,
    module.syncstorage.ingress,
    module.vaultwarden.ingress,
    # module.voidrepo.ingress,
    module.wakapi.ingress,
    module.whoami.ingress,
  ]
}

# Service authentication layer
module "auth" {
  source         = "./auth"
  versions       = var.versions.auth
  secrets        = var.secrets.auth
  target         = var.cluster.node-3.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "atuin" {
  source         = "./atuin"
  versions       = var.versions.atuin
  secrets        = var.secrets.atuin
  target         = var.cluster.node-1.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "forgejo" {
  source          = "./forgejo"
  versions        = var.versions.forgejo
  secrets         = var.secrets.forgejo
  target          = var.cluster.node-1.target
  public_domain   = var.public_domain
  private_domain  = var.private_domain
  timezone        = var.timezone
  trusted_proxies = local.mesh_cidr
  depends_on      = [null_resource.post_server, module.linstor]
}

# module "homeassistant" {
#   source         = "./homeassistant"
#   versions       = var.versions.homeassistant
#   target         = var.cluster.node-1.target
#   private_domain = var.private_domain
#   timezone       = var.timezone
#   depends_on     = [null_resource.post_server, module.linstor]
# }

# module "immich" {
#   source         = "./immich"
#   versions       = var.versions.immich
#   secrets        = var.secrets.immich
#   target         = var.cluster.node-4.target
#   storage_pool   = incus_storage_volume.immich.pool
#   storage_source = incus_storage_volume.immich.name
#   public_domain  = var.public_domain
#   private_domain = var.private_domain
#   timezone       = var.timezone
#   depends_on     = [null_resource.post_server, module.linstor]
# }

# module "jellyfin" {
#   source         = "./jellyfin"
#   versions       = var.versions.jellyfin
#   secrets        = var.secrets.jellyfin
#   target         = var.cluster.node-4.target
#   media_pool     = incus_storage_volume.media.pool
#   media_source   = incus_storage_volume.media.name
#   private_domain = var.private_domain
#   timezone       = var.timezone
#   depends_on     = [null_resource.post_server, module.linstor]
# }

# module "kavita" {
#   source         = "./kavita"
#   versions       = var.versions.kavita
#   target         = var.cluster.node-4.target
#   media_pool     = incus_storage_volume.media.pool
#   media_source   = incus_storage_volume.media.name
#   private_domain = var.private_domain
#   timezone       = var.timezone
#   depends_on     = [null_resource.post_server, module.linstor]
# }

module "metrics" {
  source        = "./metrics"
  versions      = var.versions.metrics
  secrets       = var.secrets.metrics
  members       = local.members
  target        = var.cluster.node-2.target
  public_domain = var.public_domain
  timezone      = var.timezone
  depends_on    = [null_resource.post_server, module.linstor]
}

# module "navidrome" {
#   source         = "./navidrome"
#   versions       = var.versions.navidrome
#   secrets        = var.secrets.navidrome
#   target         = var.cluster.node-4.target
#   media_pool     = incus_storage_volume.media.pool
#   media_source   = incus_storage_volume.media.name
#   public_domain  = var.public_domain
#   private_domain = var.private_domain
#   depends_on     = [null_resource.post_server, module.linstor]
# }

module "notify" {
  source         = "./notify"
  versions       = var.versions.notify
  secrets        = var.secrets.notify
  target         = var.cluster.node-2.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "paperless" {
  source         = "./paperless"
  versions       = var.versions.paperless
  secrets        = var.secrets.paperless
  target         = var.cluster.node-3.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

# module "qbittorrent" {
#   source          = "./qbittorrent"
#   versions        = var.versions.qbittorrent
#   secrets         = var.secrets.qbittorrent
#   target          = var.cluster.node-4.target
#   media_pool      = incus_storage_volume.media.pool
#   media_source    = incus_storage_volume.media.name
#   private_domain  = var.private_domain
#   timezone        = var.timezone
#   vpn_provider    = "proton"
#   # caddy and qbitmanage reach the webui over the mesh, which must bypass the VPN killswitch
#   vpn_lan_network = local.mesh_cidr
#   depends_on      = [null_resource.post_server, module.linstor]
# }

# module "sabnzbd" {
#   source         = "./sabnzbd"
#   versions       = var.versions.sabnzbd
#   target         = var.cluster.node-4.target
#   media_pool     = incus_storage_volume.media.pool
#   media_source   = incus_storage_volume.media.name
#   private_domain = var.private_domain
#   timezone       = var.timezone
#   depends_on     = [null_resource.post_server, module.linstor]
# }

# module "searxng" {
#   source          = "./searxng"
#   versions        = var.versions.searxng
#   secrets         = var.secrets.searxng
#   target          = var.cluster.node-1.target
#   public_domain   = var.public_domain
#   private_domain  = var.private_domain
#   trusted_proxies = local.mesh_cidr
#   depends_on      = [null_resource.post_server, module.linstor]
# }

# module "servarr" {
#   source         = "./servarr"
#   versions       = var.versions.servarr
#   secrets        = var.secrets.servarr
#   target         = var.cluster.node-4.target
#   media_pool     = incus_storage_volume.media.pool
#   media_source   = incus_storage_volume.media.name
#   private_domain = var.private_domain
#   timezone       = var.timezone
#   depends_on     = [null_resource.post_server, module.linstor]
# }

# module "slskd" {
#   source         = "./slskd"
#   versions       = var.versions.slskd
#   secrets        = var.secrets.slskd
#   target         = var.cluster.node-4.target
#   media_pool     = incus_storage_volume.media.pool
#   media_source   = incus_storage_volume.media.name
#   public_domain  = var.public_domain
#   private_domain = var.private_domain
#   depends_on     = [null_resource.post_server, module.linstor]
# }

module "snikket" {
  source        = "./snikket"
  versions      = var.versions.snikket
  target        = var.cluster.node-2.target
  public_domain = var.public_domain
  timezone      = var.timezone
  depends_on    = [null_resource.post_server, module.linstor]
}

module "syncstorage" {
  source         = "./syncstorage"
  versions       = var.versions.syncstorage
  secrets        = var.secrets.syncstorage
  target         = var.cluster.node-1.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "vaultwarden" {
  source         = "./vaultwarden"
  versions       = var.versions.vaultwarden
  secrets        = var.secrets.vaultwarden
  target         = var.cluster.node-3.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

# module "voidrepo" {
#   source         = "./voidrepo"
#   versions       = var.versions.voidrepo
#   target         = var.cluster.node-4.target
#   storage_pool   = incus_storage_volume.voidrepo.pool
#   storage_source = incus_storage_volume.voidrepo.name
#   public_domain  = var.public_domain
#   private_domain = var.private_domain
#   depends_on     = [null_resource.post_server, module.linstor]
# }

module "wakapi" {
  source         = "./wakapi"
  versions       = var.versions.wakapi
  secrets        = var.secrets.wakapi
  target         = var.cluster.node-2.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "whoami" {
  source         = "./whoami"
  versions       = var.versions.whoami
  target         = var.cluster.node-1.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  depends_on     = [null_resource.post_server]
}
