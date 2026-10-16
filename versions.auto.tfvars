versions = {
  atuin = {
    atuin = "18.24.0"
    db    = "18-alpine"
  }
  backups = {
    backrest        = "1.14.1"
    restic_exporter = "2.1.2"
    # standalone client, from the release matching the cluster
    incus        = "7.5.1"
    incus_sha256 = "7bd6223b369f4d693fcde695bd8549a73b5b3d403735329212483702aa22c179"
  }
  auth = {
    authelia = "4.39.28"
    lldap    = "0.6.3"
    db       = "18-alpine"
    cache    = "8-alpine"
  }
  forgejo = {
    anubis  = "1.28.1"
    forgejo = "17.0.0"
    db      = "18-alpine"
  }
  frigate = {
    frigate = "0.18.0"
  }
  home = {
    glance = "0.8.7"
  }
  homeassistant = {
    homeassistant = "2026.10.1"
    mosquitto     = "2.0.22"
  }
  immich = {
    immich = "3.3.3"
    db     = "14-vectorchord0.4.3-pgvectors0.2.0"
    cache  = "8-alpine"
  }
  ingress = {
    frpc  = "0.70.1"
    caddy = "2.11.4"
  }
  jellyfin = {
    jellyfin = "10.11.11"
  }
  kavita = {
    kavita = "0.9.1"
  }
  metrics = {
    alloy             = "1.20.1"
    blackbox_exporter = "0.29.0"
    grafana           = "13.2.4"
    loki              = "3.7.4"
    prometheus        = "3.15.0"
    smartctl_exporter = "0.15.0"
  }
  navidrome = {
    navidrome = "0.64.2"
  }
  notify = {
    gotify = "3.1.1"
    diun   = "4.33"
  }
  opencloud = {
    opencloud = "8.1.0"
  }
  paperless = {
    paperless = "3.3.2"
    db        = "18-alpine"
    cache     = "8-alpine"
  }
  qbittorrent = {
    qbittorrent = "5.2.4"
    qbitmanage  = "4.13.0"
  }
  sabnzbd = {
    sabnzbd = "5.1.3"
  }
  searxng = {
    searxng = "2026.8.22-9fea41204"
    cache   = "8-alpine"
  }
  servarr = {
    lidarr    = "testing-3.1.6.5078"
    prowlarr  = "2.6.5.5623"
    radarr    = "6.4.4.10685"
    recyclarr = "8.8.0"
    seerr     = "3.5.0"
    sonarr    = "4.0.20.3014"
  }
  slskd = {
    slskd = "0.26.1"
  }
  snikket = {
    snikket = "stable.20260611"
  }
  syncstorage = {
    syncstorage = "0.23.3"
    db          = "18-alpine"
  }
  vaultwarden = {
    vaultwarden = "1.37.3"
  }
  voidrepo = {
    caddy = "2.11.4"
  }
  wakapi = {
    wakapi = "2.18.2"
  }
  whoami = {
    whoami = "1.12.0"
  }
}
