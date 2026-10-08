apiVersion: 1

deleteDatasources:
  - name: Prometheus
    orgId: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: http://${prometheus_address}:${prometheus_port}
    editable: false
    isDefault: true
    basicAuth: false
    version: 1

  - name: Loki
    type: loki
    access: proxy
    orgId: 1
    url: http://${loki_address}:${loki_port}
    editable: false
    basicAuth: false
    version: 1
