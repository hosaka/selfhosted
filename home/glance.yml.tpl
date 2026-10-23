server:
  assets-path: /app/assets

define:
%{~ if has.prometheus }
  prometheus: &prometheus http://${addr.prometheus}/api/v1/query
%{~ endif }

# Tokyo Night. The colors are the palette's surface, primary, green and error converted to HSL.
theme:
  custom-css-file: /assets/glance.css
  background-color: 235 18.8 12.5 # 1a1b26
  primary-color: 220.8 88.7 72.4 # 7aa2f7
  positive-color: 88.8 50.5 61.2 # 9ece6a
  negative-color: 348.8 89 71.6 # f7768e
  contrast-multiplier: 0.95
  text-saturation-multiplier: 1.2
  presets:
    tokyo-night-light:
      light: true
      background-color: 230 11.1 89.4 # e1e2e7
      primary-color: 214.7 81 54.7 # 2e7de9
      positive-color: 89 34.5 34.1 # 587539
      negative-color: 342.6 91 56.3 # f52a65
      contrast-multiplier: 0.8
      text-saturation-multiplier: 3.5

branding:
  app-name: Homelab
  app-background-color: "#1a1b26"

pages:
  - name: Home
    head-widgets:
      - type: search
        search-engine: https://search.${public_domain}/search?q={QUERY}
        new-tab: true
        bangs:
          - title: YouTube
            shortcut: "!yt"
            url: https://www.youtube.com/results?search_query={QUERY}
          - title: GitHub
            shortcut: "!gh"
            url: https://github.com/search?q={QUERY}
          - title: Wikipedia
            shortcut: "!wiki"
            url: https://en.wikipedia.org/w/index.php?search={QUERY}

    columns:
      - size: small
        widgets:
          - type: clock
          - type: calendar
          - type: weather
            location: ${weather_location}
            hour-format: 24h
          - type: bookmarks
            groups:
              - links:
                  - title: selfhosted
                    url: https://code.${public_domain}/hosaka/selfhosted
                    icon: sh:forgejo

      - size: full
        widgets:
          # links go to the public hostname where a service has one
          - type: split-column
            widgets:
              - type: monitor
                title: Applications
                sites:
                  - title: OpenCloud
                    url: https://cloud.${public_domain}/
                    check-url: https://cloud.${public_domain}/status.php
                    icon: sh:opencloud
                  - title: Paperless
                    url: https://paperless.${public_domain}/
                    icon: sh:paperless-ngx
                  - title: Vaultwarden
                    url: https://vaultwarden.${public_domain}/
                    check-url: https://vaultwarden.${public_domain}/alive
                    icon: auto-invert sh:vaultwarden-dark
                  - title: Forgejo
                    url: https://code.${public_domain}/
                    check-url: https://code.${public_domain}/api/healthz
                    icon: sh:forgejo
                  - title: Snikket
                    url: https://chat.${public_domain}/
                    icon: sh:snikket
                  - title: SearXNG
                    url: https://search.${public_domain}/
                    check-url: https://search.${public_domain}/healthz
                    icon: sh:searxng
                  - title: Wakapi
                    url: https://waka.${public_domain}/
                    check-url: https://waka.${public_domain}/api/health
                    icon: sh:wakapi

              - type: monitor
                title: Infrastructure
                sites:
                  - title: Authelia
                    url: https://auth.${public_domain}/
                    check-url: https://auth.${public_domain}/api/health
                    icon: sh:authelia
                  - title: LLDAP
                    url: https://users.${private_domain}/
                    check-url: https://users.${private_domain}/health
                    icon: auto-invert sh:lldap-dark
                  - title: Grafana
                    url: https://metrics.${public_domain}/
                    check-url: https://metrics.${public_domain}/api/health
                    icon: sh:grafana
                  - title: Gotify
                    url: https://gotify.${public_domain}/
                    check-url: https://gotify.${public_domain}/health
                    icon: sh:gotify
                  - title: PeaNUT
                    url: https://ups.${private_domain}/
                    check-url: https://ups.${private_domain}/api/ping
                    icon: sh:peanut
                  - title: Backrest
                    url: https://backup.${private_domain}/
                    icon: auto-invert sh:backrest-dark
                  - title: Atuin
                    url: https://atuin.${public_domain}/
                    check-url: https://atuin.${public_domain}/healthz
                    icon: sh:atuin
                  - title: Firefox Sync
                    url: https://ffs.${public_domain}/
                    check-url: https://ffs.${public_domain}/__heartbeat__
                    icon: sh:firefox
                  - title: Void mirror
                    url: https://mirror.${public_domain}/voidlinux/
                    icon: di:void-linux
                  - title: FRP Client
                    url: https://frp.${private_domain}/
                    check-url: https://frp.${private_domain}/healthz
                    icon: di:frp
                  - title: FRP Server
                    url: https://frp.${public_domain}/
                    check-url: https://frp.${public_domain}/healthz
                    icon: di:frp

              - type: monitor
                title: Media
                sites:
                  - title: Jellyfin
                    url: https://jellyfin.${private_domain}/
                    check-url: https://jellyfin.${private_domain}/health
                    icon: sh:jellyfin
                  - title: Navidrome
                    url: https://navidrome.${public_domain}/
                    check-url: https://navidrome.${public_domain}/ping
                    icon: sh:navidrome
                  - title: Kavita
                    url: https://kavita.${private_domain}/
                    check-url: https://kavita.${private_domain}/api/health
                    icon: sh:kavita
                  - title: Immich
                    url: https://immich.${public_domain}/
                    check-url: https://immich.${public_domain}/api/server/ping
                    icon: sh:immich
                  - title: Seerr
                    url: https://seerr.${private_domain}/
                    check-url: https://seerr.${private_domain}/api/v1/status
                    icon: sh:seerr

              - type: monitor
                title: Downloads
                sites:
                  - title: Sonarr
                    url: https://sonarr.${private_domain}/
                    check-url: https://sonarr.${private_domain}/ping
                    icon: sh:sonarr
                  - title: Radarr
                    url: https://radarr.${private_domain}/
                    check-url: https://radarr.${private_domain}/ping
                    icon: sh:radarr
                  - title: Lidarr
                    url: https://lidarr.${private_domain}/
                    check-url: https://lidarr.${private_domain}/ping
                    icon: sh:lidarr
                  - title: Prowlarr
                    url: https://prowlarr.${private_domain}/
                    check-url: https://prowlarr.${private_domain}/ping
                    icon: sh:prowlarr
                  - title: qBittorrent
                    url: https://qbit.${private_domain}/
                    icon: sh:qbittorrent
                  - title: SABnzbd
                    url: https://nzb.${private_domain}/
                    icon: sh:sabnzbd
                  - title: slskd
                    url: https://slskd.${private_domain}/
                    check-url: https://slskd.${private_domain}/health
                    icon: sh:slskd

      - size: small
        widgets:
%{~ if has.prometheus }
          # Cluster, network and backup numbers straight from Prometheus, using the queries and thresholds of the
          # Grafana panels they come from, where there is one. Fixed 24h time range for availability and request counts.
          - type: custom-api
            title: Cluster
            cache: 1m
            subrequests:
              ram-use:
                url: *prometheus
                parameters:
                  query: 'sum(node_memory_MemTotal_bytes{job="cluster"}) - sum(node_memory_MemAvailable_bytes{job="cluster"}) - (sum(node_zfs_arc_size{job="cluster"}) or vector(0))'
              ram-free:
                url: *prometheus
                parameters:
                  query: 'sum(node_memory_MemAvailable_bytes{job="cluster"}) + (sum(node_zfs_arc_size{job="cluster"}) or vector(0))'
              cpu-use:
                url: *prometheus
                parameters:
                  query: '100 * (1 - avg(rate(node_cpu_seconds_total{job="cluster", mode="idle"}[5m])))'
              cpu-heat:
                url: *prometheus
                parameters:
                  query: 'topk(1, max by (node) (node_hwmon_temp_celsius{job="cluster"} * on (node, chip) group_left max by (node, chip) (node_hwmon_chip_names{job="cluster", chip_name=~"coretemp|k10temp"})))'
            template: |
              {{ define "size" }}{{ if ge . 1099511627776.0 }}{{ div . 1099511627776.0 | printf "%.1f" }} TiB{{ else }}{{ div . 1073741824.0 | printf "%.1f" }} GiB{{ end }}{{ end }}
              {{ $ramUse := .Subrequest "ram-use" }}
              {{ $ramFree := .Subrequest "ram-free" }}
              {{ $cpuUse := .Subrequest "cpu-use" }}
              {{ $cpuHeat := .Subrequest "cpu-heat" }}
              <div class="stats-row">
                <div>
                  {{ if $ramUse.JSON.Exists "data.result.0" }}
                  <div class="size-h3 color-primary">{{ template "size" ($ramUse.JSON.Float "data.result.0.value.1") }}</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">RAM USE</div>
                </div>
                <div>
                  {{ if $ramFree.JSON.Exists "data.result.0" }}
                  <div class="size-h3 color-highlight">{{ template "size" ($ramFree.JSON.Float "data.result.0.value.1") }}</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">RAM FREE</div>
                </div>
              </div>
              <div class="stats-row margin-top-15">
                <div>
                  {{ if $cpuUse.JSON.Exists "data.result.0" }}{{ $v := $cpuUse.JSON.Float "data.result.0.value.1" }}
                  <div class="size-h3 {{ if lt $v 75.0 }}color-positive{{ else if lt $v 90.0 }}stats-warn{{ else }}color-negative{{ end }}">{{ printf "%.0f" $v }}%</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">CPU USE</div>
                </div>
                <div>
                  {{ if $cpuHeat.JSON.Exists "data.result.0" }}{{ $v := $cpuHeat.JSON.Float "data.result.0.value.1" }}
                  <div class="size-h3 {{ if lt $v 75.0 }}color-positive{{ else if lt $v 85.0 }}stats-warn{{ else }}color-negative{{ end }}">{{ printf "%.0f" $v }}°C</div>
                  <div class="size-h6">CPU HEAT</div>
                  <div class="size-h6 color-subdue">{{ $cpuHeat.JSON.String "data.result.0.metric.node" }}</div>
                  {{ else }}<div class="size-h3">-</div><div class="size-h6">CPU HEAT</div>{{ end }}
                </div>
              </div>

          # Every Incus storage pool.
          - type: custom-api
            title: Storage
            cache: 1m
            subrequests:
              drive-use:
                url: *prometheus
                parameters:
                  query: 'sum(max by (pool) (incus_storage_pool_used_bytes{driver="linstor"})) + sum(incus_storage_pool_used_bytes{driver!="linstor"})'
              drive-free:
                url: *prometheus
                parameters:
                  query: '(sum(max by (pool) (incus_storage_pool_size_bytes{driver="linstor"} - incus_storage_pool_used_bytes{driver="linstor"})) or vector(0)) + (sum(incus_storage_pool_size_bytes{driver="zfs", pool!="nas"} - incus_storage_pool_used_bytes{driver="zfs", pool!="nas"}) or vector(0)) + (sum(incus_storage_pool_size_bytes{pool="nas", node=~"${storage_sources}"} - incus_storage_pool_used_bytes{pool="nas", node=~"${storage_sources}"}) or vector(0))'
              drive-heat:
                url: *prometheus
                parameters:
                  query: 'topk(1, max by (node) (smartctl_device_temperature{temperature_type="current"}))'
            template: |
              {{ define "size" }}{{ if ge . 1099511627776.0 }}{{ div . 1099511627776.0 | printf "%.1f" }} TiB{{ else }}{{ div . 1073741824.0 | printf "%.1f" }} GiB{{ end }}{{ end }}
              {{ $driveUse := .Subrequest "drive-use" }}
              {{ $driveFree := .Subrequest "drive-free" }}
              {{ $driveHeat := .Subrequest "drive-heat" }}
              <div class="stats-row">
                <div>
                  {{ if $driveUse.JSON.Exists "data.result.0" }}
                  <div class="size-h3 color-primary">{{ template "size" ($driveUse.JSON.Float "data.result.0.value.1") }}</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">DRIVE USE</div>
                </div>
                <div>
                  {{ if $driveFree.JSON.Exists "data.result.0" }}
                  <div class="size-h3 color-highlight">{{ template "size" ($driveFree.JSON.Float "data.result.0.value.1") }}</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">DRIVE FREE</div>
                </div>
              </div>
              <div class="stats-row margin-top-15">
                <div>
                  {{ if and ($driveUse.JSON.Exists "data.result.0") ($driveFree.JSON.Exists "data.result.0") }}
                  <div class="size-h3 color-highlight">{{ template "size" (add ($driveUse.JSON.Float "data.result.0.value.1") ($driveFree.JSON.Float "data.result.0.value.1")) }}</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">DRIVE TOTAL</div>
                </div>
                <div>
                  {{ if $driveHeat.JSON.Exists "data.result.0" }}{{ $v := $driveHeat.JSON.Float "data.result.0.value.1" }}
                  <div class="size-h3 {{ if lt $v 50.0 }}color-positive{{ else if lt $v 60.0 }}stats-warn{{ else }}color-negative{{ end }}">{{ printf "%.0f" $v }}°C</div>
                  <div class="size-h6">DRIVE HEAT</div>
                  <div class="size-h6 color-subdue">{{ $driveHeat.JSON.String "data.result.0.metric.node" }}</div>
                  {{ else }}<div class="size-h3">-</div><div class="size-h6">DRIVE HEAT</div>{{ end }}
                </div>
              </div>

          - type: custom-api
            title: Network
            cache: 1m
            subrequests:
              response:
                url: *prometheus
                parameters:
                  query: 'histogram_quantile(0.5, sum by (le) (rate(caddy_http_request_duration_seconds_bucket{handler="subroute"}[5m])))'
              availability:
                url: *prometheus
                parameters:
                  query: 'avg(avg_over_time(probe_success{job="blackbox"}[24h]))'
              requests:
                url: *prometheus
                parameters:
                  query: 'sum(increase(caddy_http_requests_total{handler="subroute"}[24h]))'
              requests-per-second:
                url: *prometheus
                parameters:
                  query: 'sum(rate(caddy_http_requests_total{handler="subroute"}[5m]))'
            template: |
              {{ $response := .Subrequest "response" }}
              {{ $availability := .Subrequest "availability" }}
              {{ $requests := .Subrequest "requests" }}
              {{ $rps := .Subrequest "requests-per-second" }}
              <div class="stats-row">
                <div>
                  {{ if $response.JSON.Exists "data.result.0" }}{{ $v := $response.JSON.Float "data.result.0.value.1" }}
                  <div class="size-h3 {{ if lt $v 0.5 }}color-positive{{ else if lt $v 2.0 }}stats-warn{{ else }}color-negative{{ end }}">{{ mul $v 1000.0 | printf "%.0f" }}ms</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">RESPONSE</div>
                </div>
                <div>
                  {{ if $availability.JSON.Exists "data.result.0" }}{{ $v := $availability.JSON.Float "data.result.0.value.1" }}
                  <div class="size-h3 {{ if ge $v 0.95 }}color-positive{{ else if ge $v 0.9 }}stats-warn{{ else }}color-negative{{ end }}">{{ mul $v 100.0 | printf "%.2f" }}%</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">AVAILABILITY</div>
                </div>
              </div>
              <div class="stats-row margin-top-15">
                <div>
                  {{ if $requests.JSON.Exists "data.result.0" }}
                  <div class="size-h3 color-highlight">{{ $requests.JSON.Float "data.result.0.value.1" | toInt | formatNumber }}</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">REQUESTS</div>
                </div>
                <div>
                  {{ if $rps.JSON.Exists "data.result.0" }}
                  <div class="size-h3 color-highlight">{{ $rps.JSON.Float "data.result.0.value.1" | printf "%.1f" }}</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">REQUESTS/SEC</div>
                </div>
              </div>
%{~ if backup_repository != null }

          # Next backup, is worked out from the schedule using glance's local time.
          - type: custom-api
            title: Backups
            cache: 1m
            subrequests:
              snapshots:
                url: *prometheus
                parameters:
                  query: 'restic_snapshots_total{repository="${backup_repository}"}'
              size:
                url: *prometheus
                parameters:
                  query: 'restic_size_total{repository="${backup_repository}"}'
              last:
                url: *prometheus
                parameters:
                  query: 'max(restic_backup_timestamp{repository="${backup_repository}"})'
            template: |
              {{ $snapshots := .Subrequest "snapshots" }}
              {{ $size := .Subrequest "size" }}
              {{ $last := .Subrequest "last" }}
              <div class="stats-row">
                <div>
                  {{ if $snapshots.JSON.Exists "data.result.0" }}
                  <div class="size-h3 color-highlight">{{ $snapshots.JSON.Float "data.result.0.value.1" | printf "%.0f" }}</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">SNAPSHOTS</div>
                </div>
                <div>
                  {{ if $size.JSON.Exists "data.result.0" }}{{ $v := $size.JSON.Float "data.result.0.value.1" }}
                  <div class="size-h3 color-highlight">{{ div $v 1073741824.0 | printf "%.0f" }} GiB</div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">SIZE</div>
                </div>
              </div>
              <div class="stats-row margin-top-15">
                <div>
                  {{ if $last.JSON.Exists "data.result.0" }}{{ $t := parseTime "unix" ($last.JSON.Float "data.result.0.value.1" | printf "%.0f") }}
                  {{/* stale after 26h, like the Backups dashboard's Stale plans */}}
                  <div class="size-h3 {{ if lt ((now).Sub $t) (duration "26h") }}color-positive{{ else }}color-negative{{ end }}" {{ toRelativeTime $t }}></div>
                  {{ else }}<div class="size-h3">-</div>{{ end }}
                  <div class="size-h6">LAST</div>
                </div>
%{~ if backup_offset != null }
                <div>
                  {{ $next := (startOfDay now).Add (duration "${backup_offset}") }}
                  {{ if $next.Before now }}{{ $next = $next.Add (duration "24h") }}{{ end }}
                  <div class="size-h3 color-highlight" {{ toRelativeTime $next }}></div>
                  <div class="size-h6">NEXT</div>
                </div>
%{~ endif }
              </div>
%{~ endif }
%{~ endif }
%{~ if has.peanut }

          # Straight from PeaNUT, the status flags aren't in its Prometheus metrics.
          - type: custom-api
            title: UPS
            cache: 1m
            url: http://${addr.peanut}/api/v1/devices/ups
            template: |
              {{ if .JSON.Exists "ups\\.status" }}
              {{ $status := .JSON.String "ups\\.status" }}
              {{ $charge := .JSON.Float "battery\\.charge" }}
              {{ $load := .JSON.Float "ups\\.load" }}
              <div class="stats-row">
                <div>
                  <div class="size-h3 {{ if ge $charge 80.0 }}color-positive{{ else if ge $charge 50.0 }}stats-warn{{ else }}color-negative{{ end }}">{{ printf "%.0f" $charge }}%</div>
                  <div class="size-h6">CHARGE</div>
                </div>
                <div>
                  <div class="size-h3 color-highlight">{{ div (.JSON.Float "battery\\.runtime") 60.0 | printf "%.0f" }} min</div>
                  <div class="size-h6">RUNTIME</div>
                </div>
              </div>
              <div class="stats-row margin-top-15">
                <div>
                  <div class="size-h3 {{ if lt $load 60.0 }}color-positive{{ else if lt $load 80.0 }}stats-warn{{ else }}color-negative{{ end }}">{{ printf "%.0f" $load }}%</div>
                  <div class="size-h6">LOAD</div>
                  {{ if .JSON.Exists "ups\\.realpower\\.nominal" }}<div class="size-h6 color-subdue">{{ div (mul $load (.JSON.Float "ups\\.realpower\\.nominal")) 100.0 | printf "%.0f" }} W</div>{{ end }}
                </div>
                <div>
                  {{ if findMatch "\\b(LB|FSD)\\b" $status }}<div class="size-h3 color-negative">Low battery</div>
                  {{ else if findMatch "\\bOB\\b" $status }}<div class="size-h3 stats-warn">On battery</div>
                  {{ else if findMatch "\\bOL\\b" $status }}<div class="size-h3 color-positive">Online</div>
                  {{ else }}<div class="size-h3">{{ $status }}</div>{{ end }}
                  <div class="size-h6">STATUS</div>
                </div>
              </div>
              {{ else }}
              <p class="color-negative">UPS is unavailable</p>
              {{ end }}
%{~ endif }

  - name: Metrics
    columns:
      - size: full
        widgets:
%{~ if has.sonarr || has.radarr || has.lidarr || has.prowlarr }
          - type: custom-api
            title: Media
            cache: 10m
            subrequests:
%{~ if has.sonarr }
              sonarr:
                url: http://${addr.sonarr}/api/v3/series
                headers:
                  X-Api-Key: $${SONARR_API_KEY}
%{~ endif }
%{~ if has.radarr }
              radarr:
                url: http://${addr.radarr}/api/v3/movie
                headers:
                  X-Api-Key: $${RADARR_API_KEY}
%{~ endif }
%{~ if has.lidarr }
              lidarr:
                url: http://${addr.lidarr}/api/v1/artist
                headers:
                  X-Api-Key: $${LIDARR_API_KEY}
%{~ endif }
%{~ if has.prowlarr }
              prowlarr:
                url: http://${addr.prowlarr}/api/v1/indexerstatus
                headers:
                  X-Api-Key: $${PROWLARR_API_KEY}
%{~ endif }
            template: |
              {{ define "size" }}{{ if ge . 1099511627776.0 }}{{ div . 1099511627776.0 | printf "%.1f" }} TiB{{ else }}{{ div . 1073741824.0 | printf "%.0f" }} GiB{{ end }}{{ end }}
%{~ if has.sonarr }
              {{ $shows := (.Subrequest "sonarr").JSON.Array "" }}
              {{ $showsSize := 0.0 }}{{ range $shows }}{{ $showsSize = add $showsSize (.Float "statistics.sizeOnDisk") }}{{ end }}
              <div class="app-row">
                <a class="app-name" href="https://sonarr.${private_domain}/" target="_blank" rel="noreferrer">Sonarr</a>
                <div><div>{{ template "size" $showsSize }}</div><div>SIZE</div></div>
                <div><div>{{ len $shows }}</div><div>SHOWS</div></div>
              </div>
%{~ endif }
%{~ if has.radarr }
              {{ $movies := (.Subrequest "radarr").JSON.Array "" }}
              {{ $moviesSize := 0.0 }}{{ range $movies }}{{ $moviesSize = add $moviesSize (.Float "sizeOnDisk") }}{{ end }}
              <div class="app-row">
                <a class="app-name" href="https://radarr.${private_domain}/" target="_blank" rel="noreferrer">Radarr</a>
                <div><div>{{ template "size" $moviesSize }}</div><div>SIZE</div></div>
                <div><div>{{ len $movies }}</div><div>MOVIES</div></div>
              </div>
%{~ endif }
%{~ if has.lidarr }
              {{ $songs := 0.0 }}{{ $songsSize := 0.0 }}
              {{ range (.Subrequest "lidarr").JSON.Array "" }}{{ $songs = add $songs (.Float "statistics.trackFileCount") }}{{ $songsSize = add $songsSize (.Float "statistics.sizeOnDisk") }}{{ end }}
              <div class="app-row">
                <a class="app-name" href="https://lidarr.${private_domain}/" target="_blank" rel="noreferrer">Lidarr</a>
                <div><div>{{ template "size" $songsSize }}</div><div>SIZE</div></div>
                <div><div>{{ printf "%.0f" $songs }}</div><div>SONGS</div></div>
              </div>
%{~ endif }
%{~ if has.prowlarr }
              {{ $failing := 0.0 }}
              {{ range (.Subrequest "prowlarr").JSON.Array "" }}{{ $until := .String "disabledTill" }}{{ if and (ne $until "") ((parseTime "RFC3339" $until).After now) }}{{ $failing = add $failing 1.0 }}{{ end }}{{ end }}
              <div class="app-row">
                <a class="app-name" href="https://prowlarr.${private_domain}/" target="_blank" rel="noreferrer">Prowlarr</a>
                <div class="span-2"><div class="{{ if eq $failing 0.0 }}color-positive{{ else }}color-negative{{ end }}">{{ printf "%.0f" $failing }}</div><div>FAILING INDEXERS</div></div>
              </div>
%{~ endif }
%{~ endif }


  - name: Social
    columns:
      - size: full
        widgets: []
