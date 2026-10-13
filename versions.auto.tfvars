versions = {
  atuin = {
    atuin = "18.18.0"
    db    = "18-alpine"
  }
  auth = {
    authelia = "4.39.20"
    lldap    = "0.6.3"
    db       = "18-alpine"
    cache    = "8-alpine"
  }
  forgejo = {
    anubis  = "1.26.2"
    forgejo = "16.0.1"
    db      = "18-alpine"
  }
  frigate = {
    frigate = "0.17.2"
  }
  homeassistant = {
    homeassistant = "2026.7.4"
    mosquitto     = "2.0.22"
  }
  immich = {
    immich = "3.3.0"
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
    kavita = "0.9.0"
  }
  metrics = {
    alloy             = "1.20.1"
    grafana           = "13.1.1"
    loki              = "3.7.4"
    prometheus        = "3.13.2"
    smartctl_exporter = "0.15.0"
  }
  navidrome = {
    navidrome = "0.63.2"
  }
  notify = {
    gotify = "3.0.0"
    diun   = "4.33"
  }
  paperless = {
    paperless = "3.0.4"
    db        = "18-alpine"
    cache     = "8-alpine"
  }
  qbittorrent = {
    qbittorrent = "5.2.3"
    qbitmanage  = "4.11.0"
  }
  sabnzbd = {
    sabnzbd = "5.0.4"
  }
  searxng = {
    searxng = "2026.8.22-9fea41204"
    cache   = "8-alpine"
  }
  servarr = {
    lidarr    = "pr-plugins-3.1.2.4913"
    prowlarr  = "2.5.2.5491"
    radarr    = "6.3.0.10514"
    recyclarr = "8.7.0"
    seerr     = "3.4.0"
    sonarr    = "4.0.19.2979"
  }
  slskd = {
    slskd = "0.26.0"
  }
  snikket = {
    snikket = "stable.20260611"
  }
  syncstorage = {
    syncstorage = "0.23.3"
    db          = "18-alpine"
  }
  vaultwarden = {
    # todo: we should be at 1.37.3 here
    vaultwarden = "1.37.2"
  }
  voidrepo = {
    caddy = "2.11.4"
  }
  wakapi = {
    wakapi = "2.17.5"
  }
  whoami = {
    whoami = "1.12.0"
  }
}
