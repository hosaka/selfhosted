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
    module.backups.ingress,
    module.forgejo.ingress,
    # module.homeassistant.ingress,
    module.immich.ingress,
    module.jellyfin.ingress,
    module.kavita.ingress,
    module.metrics.ingress,
    module.navidrome.ingress,
    module.notify.ingress,
    module.paperless.ingress,
    module.qbittorrent.ingress,
    module.sabnzbd.ingress,
    module.searxng.ingress,
    module.servarr.ingress,
    module.slskd.ingress,
    module.snikket.ingress,
    module.syncstorage.ingress,
    module.vaultwarden.ingress,
    module.voidrepo.ingress,
    module.wakapi.ingress,
    module.whoami.ingress,
  ]
}

module "backups" {
  source              = "./backups"
  versions            = var.versions.backups
  secrets             = var.secrets.backups
  target              = var.cluster.node-4.target
  restic_pool         = incus_storage_pool.nas.name
  cluster_address     = local.members[var.cluster.node-4.target].address
  cluster_certificate = file("${path.root}/incus/cluster.crt")
  private_domain      = var.private_domain
  timezone            = var.timezone
  depends_on          = [null_resource.post_server, module.linstor]

  sources = [
    module.auth.backups,
    module.notify.backups,
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

module "immich" {
  source         = "./immich"
  versions       = var.versions.immich
  secrets        = var.secrets.immich
  target         = var.cluster.node-4.target
  storage_pool   = incus_storage_volume.immich.pool
  storage_source = incus_storage_volume.immich.name
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "jellyfin" {
  source         = "./jellyfin"
  versions       = var.versions.jellyfin
  secrets        = var.secrets.jellyfin
  target         = var.cluster.node-4.target
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "kavita" {
  source         = "./kavita"
  versions       = var.versions.kavita
  target         = var.cluster.node-4.target
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "metrics" {
  source         = "./metrics"
  versions       = var.versions.metrics
  secrets        = var.secrets.metrics
  members        = local.members
  target         = var.cluster.node-2.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  # `incus query /os/1.0/system/storage?target=<member>` lists the drives
  smart_devices = {
    (var.cluster.node-1.target) = [
      "/dev/disk/by-id/nvme-KXG6AZNV256G_TOSHIBA_305F70ONF6B1",
      "/dev/disk/by-id/nvme-KXG6AZNV256G_TOSHIBA_50MF3DS2F6C1",
    ]
    (var.cluster.node-2.target) = [
      "/dev/disk/by-id/nvme-KXG6AZNV256G_TOSHIBA_305F70CWF6B1",
      "/dev/disk/by-id/nvme-KXG6AZNV256G_TOSHIBA_50MF34WKF6C1",
    ]
    (var.cluster.node-3.target) = [
      "/dev/disk/by-id/nvme-KXG6AZNV256G_TOSHIBA_305F70EIF6B1",
      "/dev/disk/by-id/nvme-KXG6AZNV256G_TOSHIBA_50QFA01HF6C1",
    ]
    (var.cluster.node-4.target) = [
      "/dev/disk/by-id/nvme-KXG6AZNV256G_TOSHIBA_50MF386PF6C1",
      "/dev/disk/by-id/ata-KINGSTON_SQ500S37240G_50026B7784A8E6B0",
      "/dev/disk/by-id/ata-KINGSTON_SQ500S37240G_50026B7784D51AD1",
      "/dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_VAKD8J6L",
      "/dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_VAKEE7RL",
      "/dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_VDGBKXND",
      "/dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_VDGLA6GD",
      "/dev/disk/by-id/ata-WDC_WD80EFAX-68KNBN0_VDJ0YV7K",
    ]
  }
  linstor_address  = module.linstor.linstor_api_address
  caddy_address    = module.ingress.caddy_metrics_address
  frps_address     = module.ingress.frps_metrics_address
  authelia_address = module.auth.authelia_metrics_address
  immich_addresses = module.immich.metrics_addresses
  probes = {
    auth        = module.auth.probes
    atuin       = module.atuin.probes
    backups     = module.backups.probes
    forgejo     = module.forgejo.probes
    immich      = module.immich.probes
    jellyfin    = module.jellyfin.probes
    kavita      = module.kavita.probes
    metrics     = module.metrics.probes
    navidrome   = module.navidrome.probes
    notify      = module.notify.probes
    paperless   = module.paperless.probes
    qbittorrent = module.qbittorrent.probes
    sabnzbd     = module.sabnzbd.probes
    searxng     = module.searxng.probes
    servarr     = module.servarr.probes
    slskd       = module.slskd.probes
    snikket     = module.snikket.probes
    syncstorage = module.syncstorage.probes
    vaultwarden = module.vaultwarden.probes
    voidrepo    = module.voidrepo.probes
    wakapi      = module.wakapi.probes
    whoami      = module.whoami.probes
  }
  log_collectors = keys(local.members)
  depends_on     = [null_resource.post_server, module.linstor]
}

module "navidrome" {
  source         = "./navidrome"
  versions       = var.versions.navidrome
  secrets        = var.secrets.navidrome
  target         = var.cluster.node-4.target
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  public_domain  = var.public_domain
  private_domain = var.private_domain
  depends_on     = [null_resource.post_server, module.linstor]
}

module "notify" {
  source         = "./notify"
  versions       = var.versions.notify
  secrets        = var.secrets.notify
  target         = var.cluster.node-2.target
  snapshots      = local.volume_snapshots
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

module "qbittorrent" {
  source         = "./qbittorrent"
  versions       = var.versions.qbittorrent
  secrets        = var.secrets.qbittorrent
  target         = var.cluster.node-4.target
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "sabnzbd" {
  source         = "./sabnzbd"
  versions       = var.versions.sabnzbd
  target         = var.cluster.node-4.target
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "searxng" {
  source          = "./searxng"
  versions        = var.versions.searxng
  secrets         = var.secrets.searxng
  target          = var.cluster.node-1.target
  public_domain   = var.public_domain
  private_domain  = var.private_domain
  trusted_proxies = local.mesh_cidr
  depends_on      = [null_resource.post_server, module.linstor]
}

module "servarr" {
  source         = "./servarr"
  versions       = var.versions.servarr
  secrets        = var.secrets.servarr
  target         = var.cluster.node-4.target
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "slskd" {
  source         = "./slskd"
  versions       = var.versions.slskd
  secrets        = var.secrets.slskd
  target         = var.cluster.node-4.target
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  public_domain  = var.public_domain
  private_domain = var.private_domain
  depends_on     = [null_resource.post_server, module.linstor]
}

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

module "voidrepo" {
  source         = "./voidrepo"
  versions       = var.versions.voidrepo
  target         = var.cluster.node-4.target
  storage_pool   = incus_storage_volume.voidrepo.pool
  storage_source = incus_storage_volume.voidrepo.name
  public_domain  = var.public_domain
  private_domain = var.private_domain
  depends_on     = [null_resource.post_server, module.linstor]
}

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
