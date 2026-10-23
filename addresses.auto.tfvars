# Fixed addresses on the ovn network, with the MAC of each instance's NIC, per module. See docs/ovn-migration.md.
addresses = {
  atuin = {
    atuin          = { hwaddr = "10:66:6a:fe:55:8a", ipv4 = "10.42.0.23" }
    atuin_database = { hwaddr = "10:66:6a:5c:3d:15", ipv4 = "10.42.0.24" }
  }
  auth = {
    authelia          = { hwaddr = "10:66:6a:68:64:31", ipv4 = "10.42.0.47" }
    authelia_database = { hwaddr = "10:66:6a:3a:9d:99", ipv4 = "10.42.0.48" }
    authelia_valkey   = { hwaddr = "10:66:6a:77:84:d5", ipv4 = "10.42.0.49" }
    lldap             = { hwaddr = "10:66:6a:60:db:34", ipv4 = "10.42.0.50" }
  }
  backups = {
    backrest            = { hwaddr = "10:66:6a:05:47:c1", ipv4 = "10.42.0.51" }
    restic_exporter_nas = { hwaddr = "10:66:6a:e8:a1:2f", ipv4 = "10.42.0.52" }
    restic_exporter_s3  = { hwaddr = "10:66:6a:97:c6:a8", ipv4 = "10.42.0.53" }
  }
  forgejo = {
    forgejo          = { hwaddr = "10:66:6a:3b:e5:1e", ipv4 = "10.42.0.25" }
    forgejo_anubis   = { hwaddr = "10:66:6a:1b:e3:3d", ipv4 = "10.42.0.26" }
    forgejo_database = { hwaddr = "10:66:6a:35:22:69", ipv4 = "10.42.0.27" }
  }
  frigate = {
    frigate = { hwaddr = "02:a6:25:c8:93:13", ipv4 = "10.42.0.78" }
  }
  home = {
    glance = { hwaddr = "10:66:6a:c2:de:0e", ipv4 = "10.42.0.77" }
  }
  homeassistant = {
    homeassistant = { hwaddr = "02:4c:75:78:f0:14", ipv4 = "10.42.0.79" }
  }
  immich = {
    immich                  = { hwaddr = "10:66:6a:c5:be:fa", ipv4 = "10.42.0.28" }
    immich_machine_learning = { hwaddr = "10:66:6a:fb:94:c6", ipv4 = "10.42.0.29" }
    immich_database         = { hwaddr = "10:66:6a:2a:a0:b4", ipv4 = "10.42.0.30" }
    immich_valkey           = { hwaddr = "10:66:6a:3d:49:83", ipv4 = "10.42.0.31" }
  }
  ingress = {
    caddy = { hwaddr = "10:66:6a:9b:06:fe", ipv4 = "10.42.0.10" }
    frpc  = { hwaddr = "10:66:6a:eb:f7:d4", ipv4 = "10.42.0.11" }
  }
  jellyfin = {
    jellyfin = { hwaddr = "10:66:6a:90:59:99", ipv4 = "10.42.0.58" }
  }
  kavita = {
    kavita = { hwaddr = "10:66:6a:0e:79:c2", ipv4 = "10.42.0.32" }
  }
  metrics = {
    prometheus               = { hwaddr = "10:66:6a:23:75:b2", ipv4 = "10.42.0.65" }
    grafana                  = { hwaddr = "10:66:6a:80:26:9c", ipv4 = "10.42.0.66" }
    loki                     = { hwaddr = "10:66:6a:d7:62:16", ipv4 = "10.42.0.67" }
    blackbox                 = { hwaddr = "10:66:6a:18:91:d9", ipv4 = "10.42.0.68" }
    alloy-node-1             = { hwaddr = "10:66:6a:7d:c3:b0", ipv4 = "10.42.0.69" }
    alloy-node-2             = { hwaddr = "10:66:6a:16:ee:a9", ipv4 = "10.42.0.70" }
    alloy-node-3             = { hwaddr = "10:66:6a:04:a8:c4", ipv4 = "10.42.0.71" }
    alloy-node-4             = { hwaddr = "10:66:6a:fc:35:7e", ipv4 = "10.42.0.72" }
    smartctl-exporter-node-1 = { hwaddr = "10:66:6a:9c:6b:4e", ipv4 = "10.42.0.73" }
    smartctl-exporter-node-2 = { hwaddr = "10:66:6a:2c:22:e1", ipv4 = "10.42.0.74" }
    smartctl-exporter-node-3 = { hwaddr = "10:66:6a:b1:18:30", ipv4 = "10.42.0.75" }
    smartctl-exporter-node-4 = { hwaddr = "10:66:6a:7e:ad:ae", ipv4 = "10.42.0.76" }
  }
  navidrome = {
    navidrome = { hwaddr = "10:66:6a:6d:71:5b", ipv4 = "10.42.0.33" }
  }
  notify = {
    gotify = { hwaddr = "10:66:6a:65:54:f2", ipv4 = "10.42.0.22" }
  }
  opencloud = {
    opencloud = { hwaddr = "10:66:6a:66:55:4a", ipv4 = "10.42.0.34" }
  }
  paperless = {
    paperless          = { hwaddr = "10:66:6a:9f:e1:84", ipv4 = "10.42.0.35" }
    paperless_database = { hwaddr = "10:66:6a:14:b9:93", ipv4 = "10.42.0.36" }
    paperless_valkey   = { hwaddr = "10:66:6a:74:96:4b", ipv4 = "10.42.0.37" }
  }
  qbittorrent = {
    qbittorrent = { hwaddr = "10:66:6a:aa:1b:17", ipv4 = "10.42.0.54" }
    qbitmanage  = { hwaddr = "10:66:6a:02:66:7f", ipv4 = "10.42.0.55" }
  }
  sabnzbd = {
    sabnzbd = { hwaddr = "10:66:6a:fb:50:7e", ipv4 = "10.42.0.56" }
  }
  searxng = {
    searxng        = { hwaddr = "10:66:6a:95:f4:6f", ipv4 = "10.42.0.38" }
    searxng_valkey = { hwaddr = "10:66:6a:87:93:b6", ipv4 = "10.42.0.39" }
  }
  servarr = {
    lidarr    = { hwaddr = "10:66:6a:13:0e:c4", ipv4 = "10.42.0.59" }
    prowlarr  = { hwaddr = "10:66:6a:4f:fb:26", ipv4 = "10.42.0.60" }
    radarr    = { hwaddr = "10:66:6a:ff:6e:9b", ipv4 = "10.42.0.61" }
    recyclarr = { hwaddr = "10:66:6a:36:21:56", ipv4 = "10.42.0.62" }
    seerr     = { hwaddr = "10:66:6a:ac:03:83", ipv4 = "10.42.0.63" }
    sonarr    = { hwaddr = "10:66:6a:b3:4c:0d", ipv4 = "10.42.0.64" }
  }
  slskd = {
    slskd = { hwaddr = "10:66:6a:39:63:d6", ipv4 = "10.42.0.57" }
  }
  snikket = {
    snikket_server = { hwaddr = "10:66:6a:91:b6:cf", ipv4 = "10.42.0.40" }
    snikket_web    = { hwaddr = "10:66:6a:aa:76:d6", ipv4 = "10.42.0.41" }
  }
  syncstorage = {
    syncstorage          = { hwaddr = "10:66:6a:43:e2:4d", ipv4 = "10.42.0.42" }
    syncstorage_database = { hwaddr = "10:66:6a:bb:99:91", ipv4 = "10.42.0.43" }
  }
  ups = {
    peanut = { hwaddr = "02:62:68:62:80:2b", ipv4 = "10.42.0.12" }
  }
  vaultwarden = {
    vaultwarden = { hwaddr = "10:66:6a:f1:38:84", ipv4 = "10.42.0.44" }
  }
  voidrepo = {
    voidrepo = { hwaddr = "10:66:6a:90:ac:b2", ipv4 = "10.42.0.45" }
  }
  wakapi = {
    wakapi = { hwaddr = "10:66:6a:62:f6:36", ipv4 = "10.42.0.46" }
  }
  whoami = {
    whoami = { hwaddr = "10:66:6a:db:01:fb", ipv4 = "10.42.0.21" }
  }
}
