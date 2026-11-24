versions = {
  atuin = {
    # renovate: datasource=github-releases depName=atuinsh/atuin
    atuin = "18.25.1"
    db    = "18-alpine"
  }
  backups = {
    # renovate: datasource=github-releases depName=garethgeorge/backrest
    backrest = "1.14.1"
    # renovate: datasource=docker depName=ngosang/restic-exporter
    restic_exporter = "2.2.1"
    # standalone client, from the release matching the cluster
    incus        = "7.5.1"
    incus_sha256 = "7bd6223b369f4d693fcde695bd8549a73b5b3d403735329212483702aa22c179"
  }
  auth = {
    # renovate: datasource=github-releases depName=authelia/authelia
    authelia = "4.39.28"
    # renovate: datasource=github-releases depName=lldap/lldap
    lldap = "0.6.3"
    db    = "18-alpine"
    cache = "8-alpine"
  }
  forgejo = {
    go_away = "latest@sha256:68e27b10e95b0de30fc653150d141407101079511cea67a73e95be80dd19f913"
    # renovate: datasource=forgejo-releases depName=forgejo/forgejo registryUrl=https://codeberg.org
    forgejo = "17.0.2"
    db      = "18-alpine"
  }
  frigate = {
    frigate = "0.18.0"
  }
  home = {
    # renovate: datasource=docker depName=glanceapp/glance
    glance = "0.8.8"
  }
  homeassistant = {
    homeassistant = "2026.10.1"
    mosquitto     = "2.0.22"
  }
  immich = {
    # renovate: datasource=github-releases depName=immich-app/immich
    immich = "3.4.2"
    db     = "14-vectorchord0.4.3-pgvectors0.2.0"
    cache  = "8-alpine"
  }
  ingress = {
    # renovate: datasource=github-releases depName=fatedier/frp
    frpc = "0.72.0"
    # renovate: datasource=docker depName=ghcr.io/hosaka/caddy-desec versioning=regex:^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)-(?<build>\d+)$
    caddy = "2.11.7-1"
  }
  jellyfin = {
    # renovate: datasource=github-releases depName=jellyfin/jellyfin
    jellyfin = "12.4"
  }
  kavita = {
    # renovate: datasource=github-releases depName=Kareadita/Kavita
    kavita = "0.9.1"
  }
  metrics = {
    # renovate: datasource=docker depName=grafana/alloy
    alloy = "1.22.0"
    # renovate: datasource=docker depName=prom/blackbox-exporter
    blackbox_exporter = "0.29.1"
    # renovate: datasource=github-releases depName=grafana/grafana
    grafana = "13.3.1"
    # renovate: datasource=github-releases depName=grafana/loki
    loki = "3.7.10"
    # renovate: datasource=github-releases depName=prometheus/prometheus
    prometheus = "3.16.0"
    # renovate: datasource=docker depName=prometheuscommunity/smartctl-exporter
    smartctl_exporter = "0.15.0"
  }
  navidrome = {
    # renovate: datasource=github-releases depName=navidrome/navidrome
    navidrome = "0.64.2"
  }
  notify = {
    # renovate: datasource=github-releases depName=gotify/server
    gotify = "3.1.1"
  }
  opencloud = {
    # renovate: datasource=docker depName=opencloudeu/opencloud-rolling
    opencloud = "9.2.0"
  }
  ovn = {
    ovn = "26.09"
  }
  paperless = {
    # renovate: datasource=github-releases depName=paperless-ngx/paperless-ngx
    paperless = "3.5.1"
    db        = "18-alpine"
    cache     = "8-alpine"
  }
  qbittorrent = {
    # renovate: datasource=github-releases depName=qbittorrent/qBittorrent extractVersion=^release-(?<version>.+)$
    qbittorrent = "5.3.0"
    # renovate: datasource=github-releases depName=StuffAnThings/qbit_manage
    qbitmanage = "4.15.0"
  }
  romm = {
    # renovate: datasource=github-releases depName=rommapp/romm
    romm = "5.4.1"
    db   = "18-alpine"
  }
  sabnzbd = {
    # renovate: datasource=github-releases depName=sabnzbd/sabnzbd
    sabnzbd = "5.1.3"
  }
  searxng = {
    searxng = "2026.11.23-a7163d091"
    cache   = "8-alpine"
  }
  servarr = {
    # renovate: datasource=docker depName=ghcr.io/hotio/lidarr versioning=regex:^testing-(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)\.(?<build>\d+)$
    lidarr = "testing-3.2.1.5196"
    # renovate: datasource=github-releases depName=Prowlarr/Prowlarr
    prowlarr = "3.0.2.5780"
    # renovate: datasource=github-releases depName=Radarr/Radarr
    radarr = "7.0.3.10918"
    # renovate: datasource=github-releases depName=recyclarr/recyclarr
    recyclarr = "8.8.1"
    # renovate: datasource=github-releases depName=seerr-team/seerr
    seerr = "3.5.2"
    # renovate: datasource=github-releases depName=Sonarr/Sonarr
    sonarr = "4.0.20.3014"
  }
  silverbullet = {
    # renovate: datasource=github-releases depName=silverbulletmd/silverbullet
    silverbullet = "2.12.1"
  }
  slskd = {
    # renovate: datasource=github-releases depName=slskd/slskd
    slskd = "0.26.2"
  }
  snikket = {
    # renovate: datasource=docker depName=snikket/snikket-server versioning=regex:^stable\.(?<major>\d+)$
    snikket = "stable.20260611"
  }
  syncstorage = {
    # renovate: datasource=github-releases depName=mozilla-services/syncstorage-rs
    syncstorage = "0.25.1"
    db          = "18-alpine"
  }
  ups = {
    # renovate: datasource=docker depName=brandawg93/peanut
    peanut = "6.1.2"
  }
  vaultwarden = {
    # renovate: datasource=github-releases depName=dani-garcia/vaultwarden
    vaultwarden = "1.37.5"
  }
  voidrepo = {
    caddy = "2.11.4"
  }
  wakapi = {
    # renovate: datasource=github-releases depName=muety/wakapi
    wakapi = "2.18.2"
  }
  website = {
    # renovate: datasource=github-releases depName=getzola/zola
    zola  = "0.23.6"
    caddy = "2.11.4"
  }
  whoami = {
    whoami = "1.12.0"
  }
}
