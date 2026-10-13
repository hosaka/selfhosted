global:
  # The Prometheus default value is 1m.
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "cluster"
    metrics_path: "/1.0/metrics"
    scheme: "https"
    static_configs:
%{~ for name, addr in metrics_targets }
      - targets: ["${addr}"]
        labels: { node: "${name}" }
%{~ endfor }
    tls_config:
      cert_file: "/etc/prometheus/tls/metrics.crt"
      key_file: "/etc/prometheus/tls/metrics.key"
      insecure_skip_verify: true

  # the exporter only refreshes its smartctl readings every 60s
  - job_name: "smartctl"
    scrape_interval: 60s
    static_configs:
%{~ for name, addr in smartctl_targets }
      - targets: ["${addr}"]
        labels: { node: "${name}" }
%{~ endfor }

  # the monitoring stack itself
  - job_name: "prometheus"
    static_configs:
      - targets: ["127.0.0.1:${prometheus_port}"]

  - job_name: "loki"
    static_configs:
      - targets: ["${loki_target}"]

  - job_name: "alloy"
    static_configs:
%{~ for name, addr in alloy_targets }
      - targets: ["${addr}"]
        labels: { node: "${name}" }
%{~ endfor }

  # the controller reports the state of every satellite, resource and storage pool
  - job_name: "linstor"
    static_configs:
      - targets: ["${linstor_target}"]

  # logins, second factor checks and access-control
  - job_name: "authelia"
    static_configs:
      - targets: ["${authelia_target}"]

  # immich's api and job worker. queue job and repository method names are part of the metric names,
  # these rules move them into labels so `rate()` and `sum by ()` work
  - job_name: "immich"
    static_configs:
%{~ for worker, addr in immich_targets }
      - targets: ["${addr}"]
        labels: { worker: "${worker}" }
%{~ endfor }
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: "immich_.+_repository_.+_duration_bucket"
        action: drop
      - source_labels: [__name__]
        regex: "immich_queues_(.+)_active"
        target_label: queue
      - source_labels: [__name__]
        regex: "immich_queues_(.+)_active"
        target_label: __name__
        replacement: "immich_queue_active"
      - source_labels: [__name__]
        regex: "immich_queues_(.+)_started_total"
        target_label: queue
      - source_labels: [__name__]
        regex: "immich_queues_(.+)_started_total"
        target_label: __name__
        replacement: "immich_queue_started_total"
      - source_labels: [__name__]
        regex: "immich_jobs_(.+)_(success|failed|skipped)_total"
        target_label: job_name
      - source_labels: [__name__]
        regex: "immich_jobs_(.+)_(success|failed|skipped)_total"
        target_label: status
        replacement: "$2"
      - source_labels: [__name__]
        regex: "immich_jobs_(.+)_(success|failed|skipped)_total"
        target_label: __name__
        replacement: "immich_jobs_total"
      - source_labels: [__name__]
        regex: "immich_(.+)_repository_(.+)_duration_(sum|count)"
        target_label: repository
      - source_labels: [__name__]
        regex: "immich_(.+)_repository_(.+)_duration_(sum|count)"
        target_label: method
        replacement: "$2"
      - source_labels: [__name__]
        regex: "immich_(.+)_repository_(.+)_duration_(sum|count)"
        target_label: __name__
        replacement: "immich_repository_duration_milliseconds_$3"

  # service health checks, probed through the blackbox exporter
  - job_name: "blackbox"
    scrape_interval: 60s
    metrics_path: "/probe"
    params:
      module: ["http_2xx"]
    static_configs:
%{~ for p in probes }
      - targets: ["${p.url}"]
        labels: { service: "${p.service}", domain: "${p.domain}" }
%{~ endfor }
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: "${blackbox_target}"

  - job_name: "caddy"
    file_sd_configs:
      - files: ["/etc/prometheus/targets/caddy.json"]
        refresh_interval: 1m

  - job_name: "frps"
    basic_auth:
      username_file: "/etc/prometheus/secrets/frps_user"
      password_file: "/etc/prometheus/secrets/frps_password"
    file_sd_configs:
      - files: ["/etc/prometheus/targets/frps.json"]
        refresh_interval: 1m
