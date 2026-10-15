locals {
  # Alert rules by group. Each one mirrors a dashboard panel, which its notification opens.
  alert_rules = {
    availability = {
      site-down = {
        title     = "Site down"
        query     = "max by (instance, service, domain) (probe_success{job=\"blackbox\"} or (up{job=\"blackbox\"} - 1))"
        evaluator = { type = "lt", params = [1] }
        pending   = "5m"
        severity  = "critical"
        summary   = "{{ reReplaceAll \"https://([^/]+).*\" \"$1\" $labels.instance }} {{ if lt $values.A.Value 0.0 }}isn't probed, the blackbox exporter is unreachable{{ else }}is failing its health check{{ end }}"
        panel     = ["uptime", 7] # Health checks
      }
      node-down = {
        title     = "Node down"
        query     = "up{job=\"cluster\"}"
        evaluator = { type = "lt", params = [1] }
        pending   = "3m"
        severity  = "critical"
        summary   = "{{ $labels.node }}'s Incus metrics endpoint can't be scraped"
        panel     = ["monitoring", 14] # Targets
      }
      scrape-target-down = {
        title     = "Scrape target down"
        query     = "up{job!~\"cluster|frps|blackbox\"}"
        evaluator = { type = "lt", params = [1] }
        pending   = "10m"
        severity  = "warning"
        summary   = "{{ $labels.job }} at {{ $labels.instance }}{{ with $labels.node }} on {{ . }}{{ end }} can't be scraped"
        panel     = ["monitoring", 14] # Targets
      }
    }

    storage = {
      smart-failed = {
        title     = "SMART failed"
        query     = "max by (node, device) (smartctl_device_smart_status)"
        evaluator = { type = "lt", params = [1] }
        pending   = "5m"
        severity  = "critical"
        summary   = "{{ $labels.device }} on {{ $labels.node }} fails its SMART self-assessment"
        panel     = ["drive-health", 7] # Drives
      }
      bad-sectors = {
        title     = "Bad sectors"
        query     = "max by (node, device, attribute_name) (smartctl_device_attribute{attribute_value_type=\"raw\", attribute_name=~\"Current_Pending_Sector|Offline_Uncorrectable\"})"
        evaluator = { type = "gt", params = [0] }
        pending   = "5m"
        severity  = "critical"
        summary   = "{{ $labels.device }} on {{ $labels.node }} has {{ $values.A.Value }} {{ if eq $labels.attribute_name \"Current_Pending_Sector\" }}pending{{ else }}uncorrectable{{ end }} sectors"
        panel     = ["drive-health", 7] # Drives
      }
      nvme-warning = {
        title     = "NVMe warning"
        query     = "label_replace(max by (node, device) (smartctl_device_critical_warning), \"check\", \"critical warning\", \"\", \"\") or label_replace(max by (node, device) (smartctl_device_media_errors), \"check\", \"media errors\", \"\", \"\")"
        evaluator = { type = "gt", params = [0] }
        pending   = "5m"
        severity  = "critical"
        summary   = "{{ $labels.device }} on {{ $labels.node }} reports {{ $labels.check }}: {{ $values.A.Value }}"
        panel     = ["drive-health", 7] # Drives
      }
      # only reallocations, the CRC counters of the Kingston SSDs jump by 65536 now and then
      sectors-reallocated = {
        title     = "Sectors reallocated"
        query     = "max by (node, device) (smartctl_device_attribute{attribute_value_type=\"raw\", attribute_name=\"Reallocated_Sector_Ct\"}) - max by (node, device) (smartctl_device_attribute{attribute_value_type=\"raw\", attribute_name=\"Reallocated_Sector_Ct\"} offset 1h)"
        evaluator = { type = "gt", params = [0] }
        pending   = "5m"
        severity  = "warning"
        summary   = "{{ $labels.device }} on {{ $labels.node }} reallocated {{ $values.A.Value }} more sectors in the last hour"
        panel     = ["drive-health", 9] # New drive errors
      }
      drive-hot = {
        title     = "Drive hot"
        query     = "max by (node, device) (smartctl_device_temperature{temperature_type=\"current\"})"
        evaluator = { type = "gt", params = [60] }
        pending   = "15m"
        severity  = "warning"
        summary   = "{{ $labels.device }} on {{ $labels.node }} is at {{ $values.A.Value }}°C"
        panel     = ["drive-health", 8] # Temperature
      }
      nvme-worn = {
        title     = "NVMe worn"
        query     = "max by (node, device) (smartctl_device_percentage_used)"
        evaluator = { type = "gte", params = [80] }
        pending   = "5m"
        severity  = "warning"
        summary   = "{{ $labels.device }} on {{ $labels.node }} has used {{ $values.A.Value }}% of its rated endurance"
        panel     = ["drive-health", 10] # NVMe wear
      }
      drive-missing = {
        title     = "Drive missing"
        query     = "max by (node, device) (smartctl_device) or (${local.expected_drives})"
        evaluator = { type = "lt", params = [1] }
        pending   = "10m"
        severity  = "critical"
        summary   = "{{ $labels.device }} on {{ $labels.node }} stopped reporting: it's gone, or smartctl can't read it"
        panel     = ["drive-health", 7] # Drives
      }
      zfs-pool-not-online = {
        title     = "ZFS pool not online"
        query     = "max by (node, zpool) (node_zfs_zpool_state{job=\"cluster\", state=\"online\"})"
        evaluator = { type = "lt", params = [1] }
        pending   = "5m"
        severity  = "critical"
        summary   = "{{ $labels.zpool }} on {{ $labels.node }} isn't online"
        panel     = ["incus-overview", 1] # Cluster members
      }
      linstor-pool-full = {
        title     = "LINSTOR pool full"
        query     = "100 * (1 - sum by (node) (linstor_storage_pool_capacity_free_bytes{job=\"linstor\", driver!=\"DISKLESS\"}) / sum by (node) (linstor_storage_pool_capacity_total_bytes{job=\"linstor\", driver!=\"DISKLESS\"}))"
        evaluator = { type = "gt", params = [90] }
        pending   = "30m"
        severity  = "warning"
        summary   = "The LINSTOR pool on {{ $labels.node }} is {{ printf \"%.0f\" $values.A.Value }}% full"
        panel     = ["linstor-pool", 9] # Pool used
      }
      volume-full = {
        title     = "Volume full"
        query     = "max by (name, mountpoint) (100 * (1 - incus_filesystem_avail_bytes{job=\"cluster\", device=~\"/dev/drbd.+\"} / incus_filesystem_size_bytes{job=\"cluster\", device=~\"/dev/drbd.+\"}))"
        evaluator = { type = "gt", params = [90] }
        pending   = "15m"
        severity  = "warning"
        summary   = "{{ $labels.mountpoint }} on {{ $labels.name }} is {{ printf \"%.0f\" $values.A.Value }}% full"
        panel     = ["linstor-pool", 11] # Volume usage
      }
      satellite-not-online = {
        title     = "Satellite not online"
        query     = "max by (node) (linstor_node_state{job=\"linstor\"})"
        evaluator = { type = "ne", params = [2] }
        pending   = "5m"
        severity  = "warning"
        summary   = "{{ $labels.node }}'s LINSTOR satellite is {{ printf \"%.0f\" $values.A.Value${local.linstor_node_state_names} }}"
        panel     = ["linstor-pool", 8] # Satellite state
      }
      volume-unhealthy = {
        title    = "Volume unhealthy"
        query    = "max by (name, node) (max by (resource, device_path, node) (linstor_volume_state{job=\"linstor\"}) * on (device_path) group_left (name) group by (device_path, name) (${local.linstor_volume_names}) or label_replace(max by (resource, device_path, node) (linstor_volume_state{job=\"linstor\"}) unless on (device_path) group by (device_path, name) (${local.linstor_volume_names}), \"name\", \"$1\", \"resource\", \"(.*)\"))"
        math     = "$A != 1 && $A != 4" # UpToDate or Diskless
        pending  = "10m"
        severity = "critical"
        summary  = "{{ $labels.name }} on {{ $labels.node }} is {{ printf \"%.0f\" $values.A.Value${local.linstor_volume_state_names} }}"
        panel    = ["linstor-pool", 10] # Volumes
      }
      linstor-pool-errors = {
        title     = "LINSTOR pool errors"
        query     = "max by (node, storage_pool) (linstor_storage_pool_error_count{job=\"linstor\"})"
        evaluator = { type = "gt", params = [0] }
        pending   = "5m"
        severity  = "warning"
        summary   = "{{ $labels.storage_pool }} on {{ $labels.node }} reports {{ $values.A.Value }} errors"
        panel     = ["linstor-pool", 7] # Satellites
      }
    }

    hosts = {
      memory-high = {
        title     = "Memory high"
        query     = "100 * (1 - (sum by (node) (node_memory_MemAvailable_bytes{job=\"cluster\"}) + (sum by (node) (node_zfs_arc_size{job=\"cluster\"}) or sum by (node) (node_memory_MemTotal_bytes{job=\"cluster\"}) * 0)) / sum by (node) (node_memory_MemTotal_bytes{job=\"cluster\"}))"
        evaluator = { type = "gt", params = [90] }
        pending   = "10m"
        severity  = "warning"
        summary   = "{{ $labels.node }} is using {{ printf \"%.0f\" $values.A.Value }}% of its RAM, not counting the ZFS ARC"
        panel     = ["incus-overview", 1] # Cluster members
      }
      oom-kill = {
        title     = "OOM kill"
        query     = "max by (node) (clamp_min(node_vmstat_oom_kill{job=\"cluster\"} - node_vmstat_oom_kill{job=\"cluster\"} offset 1h, 0))"
        evaluator = { type = "gt", params = [0] }
        pending   = "0s"
        severity  = "warning"
        summary   = "{{ $labels.node }} killed {{ $values.A.Value }} processes for lack of memory in the last hour"
        panel     = ["incus-overview", 1] # Cluster members
      }
      cpu-hot = {
        title     = "CPU hot"
        query     = "max by (node) (node_hwmon_temp_celsius{job=\"cluster\"} * on (node, chip) group_left max by (node, chip) (node_hwmon_chip_names{job=\"cluster\", chip_name=~\"coretemp|k10temp\"}))"
        evaluator = { type = "gt", params = [85] }
        pending   = "10m"
        severity  = "warning"
        summary   = "{{ $labels.node }}'s CPU is at {{ printf \"%.0f\" $values.A.Value }}°C"
        panel     = ["incus-overview", 1] # Cluster members
      }
      root-disk-full = {
        title     = "Root disk full"
        query     = "100 * (1 - sum by (node) (node_filesystem_avail_bytes{job=\"cluster\", mountpoint=\"/\"}) / sum by (node) (node_filesystem_size_bytes{job=\"cluster\", mountpoint=\"/\"}))"
        evaluator = { type = "gt", params = [90] }
        pending   = "30m"
        severity  = "warning"
        summary   = "{{ $labels.node }}'s IncusOS root filesystem is {{ printf \"%.0f\" $values.A.Value }}% full"
        panel     = ["incus-overview", 1] # Cluster members
      }
    }
  }

  expected_drives = join(" or ", flatten([
    for node, devices in var.smart_devices : [
      for d in devices : "label_replace(label_replace(vector(0), \"node\", \"${node}\", \"\", \"\"), \"device\", \"${basename(d)}\", \"\", \"\")"
    ]
  ]))

  # the name of each mounted DRBD device's volume, from its mount point on the host
  linstor_volume_names = "label_replace(label_replace(node_filesystem_size_bytes{job=\"cluster\", device=~\"/dev/drbd.*\"}, \"device_path\", \"$1\", \"device\", \"(.*)\"), \"name\", \"$1\", \"mountpoint\", \".*/storage-pools/[^/]+/[^/]+/(?:[^_/]+_)?([^/]+)\")"

  # state numbers to names in summaries
  linstor_node_state_names = join("", [
    for i, s in ["OFFLINE", "CONNECTED", "ONLINE", "VERSION_MISMATCH", "FULL_SYNC_FAILED", "AUTHENTICATION_ERROR", "UNKNOWN", "HOSTNAME_MISMATCH", "OTHER_CONTROLLER", "AUTHENTICATED", "NO_STLT_CONN", "MISSING_EXT_TOOLS", "DUPLICATE_UNAME"] :
    " | reReplaceAll \"^${i}$\" \"${s}\""
  ])
  linstor_volume_state_names = join("", [
    for v, s in { "-1" = "Unknown", "2" = "Created", "3" = "Attached", "5" = "Inconsistent", "6" = "Failed", "7" = "Creating", "8" = "Attachable", "9" = "Attaching", "90" = "Diskless (detached)" } :
    " | reReplaceAll \"^${v}$\" \"${s}\""
  ])

  grafana_alert_rules = yamlencode({
    apiVersion = 1
    groups = [for group, rules in local.alert_rules : {
      orgId    = 1
      name     = group
      folder   = "Alerts"
      interval = "1m"
      rules = [for uid, r in rules : {
        uid       = uid
        title     = r.title
        condition = "B"
        "for"     = r.pending
        # a failing query or a metric gone missing alerts as DatasourceError or DatasourceNoData
        noDataState  = "NoData"
        execErrState = "Error"
        labels       = { severity = r.severity }
        annotations = {
          summary = r.summary
          # the panel's link, the rule's dashboardUid and panelId don't reach its alerts when provisioned
          __dashboardUid__ = r.panel[0]
          __panelId__      = tostring(r.panel[1])
        }
        data = [
          {
            refId             = "A"
            datasourceUid     = "prometheus"
            relativeTimeRange = { from = 600, to = 0 }
            model             = { refId = "A", expr = r.query, instant = true, range = false }
          },
          {
            refId         = "B"
            datasourceUid = "__expr__"
            # a threshold on A, or a math expression for conditions a threshold can't express
            model = merge(
              { refId = "B", type = can(r.math) ? "math" : "threshold", expression = can(r.math) ? r.math : "A" },
              { for k, v in { conditions = [{ evaluator = try(r.evaluator, null) }] } : k => v if !can(r.math) },
            )
          },
        ]
      }]
    }]
  })

  # Alert notifications go to gotify through a webhook, whose custom payload is a Gotify message.
  grafana_notifications = yamlencode({
    apiVersion = 1
    templates = [{
      orgId    = 1
      name     = "gotify"
      template = file("${path.module}/gotify.tmpl")
    }]
    contactPoints = [{
      orgId = 1
      name  = "Gotify"
      receivers = [{
        uid  = "gotify"
        type = "webhook"
        settings = {
          # gotify's mesh address, so alerts about the ingress or the tunnel still get through
          url                       = "${var.gotify_address}/message"
          httpMethod                = "POST"
          authorization_scheme      = "Bearer"
          authorization_credentials = sensitive(var.secrets.gotify_token)
          payload = {
            template = "{{ template \"gotify.payload\" . }}"
          }
        }
      }]
    }]
    # the root policy, it replaces whatever was set up in the UI. One notification per rule, so an
    # outage that fails many probes at once is one message listing them. Their alerts start firing
    # over two evaluations a minute apart, hence the wait.
    policies = [{
      orgId           = 1
      receiver        = "Gotify"
      group_by        = ["alertname"]
      group_wait      = "90s"
      group_interval  = "5m"
      repeat_interval = "4h"
    }]
  })
}
