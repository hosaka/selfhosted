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
