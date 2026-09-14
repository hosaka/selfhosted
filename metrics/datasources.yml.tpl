apiVersion: 1

deleteDatasources:
  - name: Prometheus
    orgId: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: http://${prometheus_address}:9090
    editable: false
    isDefault: true
    basicAuth: false
    version: 1

  - name: Loki
    type: loki
    access: proxy
    orgId: 1
    url: http://${loki_address}:3100
    editable: false
    basicAuth: false
    version: 1
