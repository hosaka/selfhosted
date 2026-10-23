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

  # where proxied requests come from, Caddy and Anubis are on the OVN network
  trusted_proxies = [var.ovn.subnet]
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

# OVN central database, the control plane of the ovn network
module "ovn" {
  source          = "./ovn"
  versions        = var.versions.ovn
  members         = local.members
  seeds           = { for name in keys(local.members) : name => try(yamldecode(file("${path.root}/incus/${name}/services.yml")), {}) }
  central         = var.ovn.central
  gateway_chassis = var.ovn.gateway_chassis
  uplink          = incus_network.lan.name
  subnet          = var.ovn.subnet
  dhcp_range      = var.ovn.dhcp_range
  gateway         = var.cluster.gateway
  depends_on = [
    null_resource.post_projects,
    null_resource.post_networks,
    null_resource.post_storage_pools,
    incus_profile.internal_default,
  ]
}

module "ups" {
  source              = "./ups"
  versions            = var.versions.ups
  addresses           = local.ovn_addresses.ups
  target              = var.cluster.node-1.target
  address             = var.ups.address
  gateway             = var.cluster.gateway
  private_domain      = var.private_domain
  cluster_address     = local.members[var.cluster.node-1.target].address
  cluster_certificate = file("${path.root}/incus/cluster.crt")
  # APC BK750M-JP, `incus query /1.0/resources?target=<member>` lists the USB devices
  usb        = { vendorid = "051d", productid = "0002" }
  depends_on = [null_resource.post_server]
}

# This is the entrypoint for all server traffic.
module "ingress" {
  source         = "./ingress"
  versions       = var.versions.ingress
  addresses      = local.ovn_addresses.ingress
  secrets        = var.secrets.ingress
  target         = var.cluster.node-3.target
  snapshots      = local.daily_snapshot
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]

  services = [
    module.auth.ingress,
    module.atuin.ingress,
    module.backups.ingress,
    module.forgejo.ingress,
    module.home.ingress,
    # module.homeassistant.ingress,
    module.immich.ingress,
    module.jellyfin.ingress,
    module.kavita.ingress,
    module.metrics.ingress,
    module.navidrome.ingress,
    module.notify.ingress,
    module.opencloud.ingress,
    module.paperless.ingress,
    module.qbittorrent.ingress,
    module.sabnzbd.ingress,
    module.searxng.ingress,
    module.servarr.ingress,
    module.slskd.ingress,
    module.snikket.ingress,
    module.syncstorage.ingress,
    module.ups.ingress,
    module.vaultwarden.ingress,
    module.voidrepo.ingress,
    module.wakapi.ingress,
    module.whoami.ingress,
  ]
}

module "backups" {
  source              = "./backups"
  versions            = var.versions.backups
  addresses           = local.ovn_addresses.backups
  secrets             = var.secrets.backups
  target              = var.cluster.node-4.target
  restic_pool         = incus_storage_pool.nas.name
  cluster_address     = local.members[var.cluster.node-4.target].address
  cluster_certificate = file("${path.root}/incus/cluster.crt")
  gotify_address      = module.notify.gotify_address
  private_domain      = var.private_domain
  timezone            = var.timezone
  depends_on          = [null_resource.post_server, module.linstor]

  sources = merge(
    module.atuin.backups,
    module.auth.backups,
    module.forgejo.backups,
    # module.homeassistant.backups,
    module.immich.backups,
    module.ingress.backups,
    module.jellyfin.backups,
    module.kavita.backups,
    module.metrics.backups,
    module.navidrome.backups,
    module.notify.backups,
    module.opencloud.backups,
    module.paperless.backups,
    module.qbittorrent.backups,
    module.sabnzbd.backups,
    module.servarr.backups,
    module.slskd.backups,
    module.snikket.backups,
    module.syncstorage.backups,
    module.vaultwarden.backups,
    module.wakapi.backups,
  )

  # on the nas pool, so they only go to the s3 repo
  nas_sources = {
    immich-library = {
      pool     = incus_storage_volume.immich.pool
      volume   = incus_storage_volume.immich.name
      excludes = ["backups/*.sql.gz"]
    }
    media = {
      pool   = incus_storage_volume.media.pool
      volume = incus_storage_volume.media.name
      paths  = ["collection/music", "collection/books"]
    }
    opencloud-files = {
      pool   = incus_storage_volume.opencloud.pool
      volume = incus_storage_volume.opencloud.name
    }
  }
}

# Service authentication layer
module "auth" {
  source         = "./auth"
  versions       = var.versions.auth
  addresses      = local.ovn_addresses.auth
  secrets        = var.secrets.auth
  target         = var.cluster.node-3.target
  snapshots      = local.daily_snapshot
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

# Users and groups in LLDAP, and by extension in Authelia.
# Skip this module with -exclude=module.users then apply module.auth first on a fresh build.
module "users" {
  source        = "./users"
  public_domain = var.public_domain

  users = var.users

  secrets = {
    authelia_password = var.secrets.auth.lldap_password
  }
}

module "atuin" {
  source         = "./atuin"
  versions       = var.versions.atuin
  addresses      = local.ovn_addresses.atuin
  secrets        = var.secrets.atuin
  target         = var.cluster.node-1.target
  snapshots      = local.daily_snapshot
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "forgejo" {
  source          = "./forgejo"
  versions        = var.versions.forgejo
  addresses       = local.ovn_addresses.forgejo
  secrets         = var.secrets.forgejo
  target          = var.cluster.node-1.target
  snapshots       = local.daily_snapshot
  public_domain   = var.public_domain
  private_domain  = var.private_domain
  timezone        = var.timezone
  trusted_proxies = local.trusted_proxies
  depends_on      = [null_resource.post_server, module.linstor]
}

module "home" {
  source         = "./home"
  versions       = var.versions.home
  addresses      = local.ovn_addresses.home
  target         = var.cluster.node-3.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone

  # every service is optional
  services = {
    prometheus = { address = module.metrics.prometheus_address }
    sonarr     = { address = module.servarr.api_addresses.sonarr, api_key = var.secrets.servarr.sonarr_api_key }
    radarr     = { address = module.servarr.api_addresses.radarr, api_key = var.secrets.servarr.radarr_api_key }
    lidarr     = { address = module.servarr.api_addresses.lidarr, api_key = var.secrets.servarr.lidarr_api_key }
    prowlarr   = { address = module.servarr.api_addresses.prowlarr, api_key = var.secrets.servarr.prowlarr_api_key }
    peanut     = { address = module.ups.peanut_address }
  }

  forward_auth = module.auth.authelia_address
  storage      = { sources = [for m, source in local.nas_sources : m if source == "nas/incus"] }
  backups      = { repository = "s3", schedule = module.backups.schedules.s3 }
  depends_on   = [null_resource.post_server]
}

# module "homeassistant" {
#   source         = "./homeassistant"
#   versions       = var.versions.homeassistant
#   addresses      = local.ovn_addresses.homeassistant
#   target         = var.cluster.node-1.target
#   snapshots      = local.daily_snapshot
#   private_domain = var.private_domain
#   timezone       = var.timezone
#   depends_on     = [null_resource.post_server, module.linstor]
# }

module "immich" {
  source         = "./immich"
  versions       = var.versions.immich
  addresses      = local.ovn_addresses.immich
  secrets        = var.secrets.immich
  target         = var.cluster.node-4.target
  snapshots      = local.daily_snapshot
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
  addresses      = local.ovn_addresses.jellyfin
  secrets        = var.secrets.jellyfin
  target         = var.cluster.node-4.target
  snapshots      = local.daily_snapshot
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "kavita" {
  source         = "./kavita"
  versions       = var.versions.kavita
  addresses      = local.ovn_addresses.kavita
  target         = var.cluster.node-4.target
  snapshots      = local.daily_snapshot
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "metrics" {
  source         = "./metrics"
  versions       = var.versions.metrics
  addresses      = local.ovn_addresses.metrics
  secrets        = var.secrets.metrics
  members        = local.members
  target         = var.cluster.node-2.target
  snapshots      = local.daily_snapshot
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
  linstor_address           = module.linstor.linstor_api_address
  caddy_address             = module.ingress.caddy_metrics_address
  frps_address              = module.ingress.frps_metrics_address
  authelia_address          = module.auth.authelia_metrics_address
  immich_addresses          = module.immich.metrics_addresses
  restic_exporter_addresses = module.backups.restic_exporter_addresses
  peanut_address            = module.ups.peanut_address
  gotify_address            = module.notify.gotify_address
  probes = {
    auth        = module.auth.probes
    atuin       = module.atuin.probes
    backups     = module.backups.probes
    forgejo     = module.forgejo.probes
    home        = module.home.probes
    immich      = module.immich.probes
    jellyfin    = module.jellyfin.probes
    kavita      = module.kavita.probes
    metrics     = module.metrics.probes
    navidrome   = module.navidrome.probes
    notify      = module.notify.probes
    opencloud   = module.opencloud.probes
    paperless   = module.paperless.probes
    qbittorrent = module.qbittorrent.probes
    sabnzbd     = module.sabnzbd.probes
    searxng     = module.searxng.probes
    servarr     = module.servarr.probes
    slskd       = module.slskd.probes
    snikket     = module.snikket.probes
    syncstorage = module.syncstorage.probes
    ups         = module.ups.probes
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
  addresses      = local.ovn_addresses.navidrome
  secrets        = var.secrets.navidrome
  target         = var.cluster.node-4.target
  snapshots      = local.daily_snapshot
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  public_domain  = var.public_domain
  private_domain = var.private_domain
  depends_on     = [null_resource.post_server, module.linstor]
}

module "notify" {
  source         = "./notify"
  versions       = var.versions.notify
  addresses      = local.ovn_addresses.notify
  secrets        = var.secrets.notify
  target         = var.cluster.node-2.target
  snapshots      = local.daily_snapshot
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "opencloud" {
  source         = "./opencloud"
  versions       = var.versions.opencloud
  addresses      = local.ovn_addresses.opencloud
  secrets        = var.secrets.opencloud
  target         = var.cluster.node-4.target
  snapshots      = local.daily_snapshot
  storage_pool   = incus_storage_volume.opencloud.pool
  storage_source = incus_storage_volume.opencloud.name
  public_domain  = var.public_domain
  depends_on     = [null_resource.post_server, module.linstor]
}

module "paperless" {
  source         = "./paperless"
  versions       = var.versions.paperless
  addresses      = local.ovn_addresses.paperless
  secrets        = var.secrets.paperless
  target         = var.cluster.node-3.target
  snapshots      = local.daily_snapshot
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "qbittorrent" {
  source         = "./qbittorrent"
  versions       = var.versions.qbittorrent
  addresses      = local.ovn_addresses.qbittorrent
  lan_network    = cidrsubnet(var.cluster.gateway, 0, 0)
  secrets        = var.secrets.qbittorrent
  target         = var.cluster.node-4.target
  snapshots      = local.daily_snapshot
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "sabnzbd" {
  source         = "./sabnzbd"
  versions       = var.versions.sabnzbd
  addresses      = local.ovn_addresses.sabnzbd
  target         = var.cluster.node-4.target
  snapshots      = local.daily_snapshot
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "searxng" {
  source          = "./searxng"
  versions        = var.versions.searxng
  addresses       = local.ovn_addresses.searxng
  secrets         = var.secrets.searxng
  target          = var.cluster.node-1.target
  public_domain   = var.public_domain
  private_domain  = var.private_domain
  trusted_proxies = local.trusted_proxies
  depends_on      = [null_resource.post_server, module.linstor]
}

module "servarr" {
  source         = "./servarr"
  versions       = var.versions.servarr
  addresses      = local.ovn_addresses.servarr
  proxy_address  = local.ovn_addresses.ingress.caddy.ipv4
  secrets        = var.secrets.servarr
  target         = var.cluster.node-4.target
  snapshots      = local.daily_snapshot
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "slskd" {
  source         = "./slskd"
  versions       = var.versions.slskd
  addresses      = local.ovn_addresses.slskd
  secrets        = var.secrets.slskd
  target         = var.cluster.node-4.target
  snapshots      = local.daily_snapshot
  media_pool     = incus_storage_volume.media.pool
  media_source   = incus_storage_volume.media.name
  public_domain  = var.public_domain
  private_domain = var.private_domain
  depends_on     = [null_resource.post_server, module.linstor]
}

module "snikket" {
  source        = "./snikket"
  versions      = var.versions.snikket
  addresses     = local.ovn_addresses.snikket
  target        = var.cluster.node-2.target
  snapshots     = local.daily_snapshot
  public_domain = var.public_domain
  timezone      = var.timezone
  depends_on    = [null_resource.post_server, module.linstor]
}

module "syncstorage" {
  source         = "./syncstorage"
  versions       = var.versions.syncstorage
  addresses      = local.ovn_addresses.syncstorage
  secrets        = var.secrets.syncstorage
  target         = var.cluster.node-1.target
  snapshots      = local.daily_snapshot
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "vaultwarden" {
  source         = "./vaultwarden"
  versions       = var.versions.vaultwarden
  addresses      = local.ovn_addresses.vaultwarden
  secrets        = var.secrets.vaultwarden
  target         = var.cluster.node-3.target
  snapshots      = local.daily_snapshot
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "voidrepo" {
  source         = "./voidrepo"
  versions       = var.versions.voidrepo
  addresses      = local.ovn_addresses.voidrepo
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
  addresses      = local.ovn_addresses.wakapi
  secrets        = var.secrets.wakapi
  target         = var.cluster.node-2.target
  snapshots      = local.daily_snapshot
  public_domain  = var.public_domain
  private_domain = var.private_domain
  timezone       = var.timezone
  depends_on     = [null_resource.post_server, module.linstor]
}

module "whoami" {
  source         = "./whoami"
  versions       = var.versions.whoami
  addresses      = local.ovn_addresses.whoami
  target         = var.cluster.node-1.target
  public_domain  = var.public_domain
  private_domain = var.private_domain
  depends_on     = [null_resource.post_server]
}
