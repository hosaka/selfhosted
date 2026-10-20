// Ships the console output of every instance on ${node} to Loki.
logging {
  level = "warn"
}

// LXC keeps writing each instance's console to <logs volume>/<instance>/console.log.
local.file_match "console" {
  path_targets = [{"__path__" = "/logs/*/console.log"}]
}

// The directory is the instance name, prefixed with "<project>_" outside the default project.
// The labels match the ones incus uses for its own events in Loki.
discovery.relabel "console" {
  targets = local.file_match.console.targets

  rule {
    source_labels = ["__path__"]
    regex         = "/logs/(?:[^_/]+_)?([^/]+)/console.log"
    target_label  = "name"
  }

  rule {
    source_labels = ["__path__"]
    regex         = "/logs/([^_/]+)_[^/]+/console.log"
    target_label  = "project"
  }

  rule {
    source_labels = ["__path__"]
    regex         = "/logs/[^_/]+/console.log"
    target_label  = "project"
    replacement   = "default"
  }
}

loki.source.file "console" {
  targets    = discovery.relabel.console.output
  forward_to = [loki.process.console.receiver]

  // the lines carry no timestamps, so skip what was written before a file was first seen
  tail_from_end = true
}

loki.process "console" {
  forward_to = [loki.write.loki.receiver]

  // ANSI color codes are kept, grafana renders them
  stage.static_labels {
    values = {
      location = "${node}",
      type     = "console",
    }
  }

  stage.label_drop {
    values = ["filename"]
  }

  // Per service log normalizers.

  // 2026-10-20T12:54:00.031Z [debug][Download Tracker]: Starting scheduled job
  stage.match {
    selector = "{name=\"seerr\"}"

    stage.multiline {
      firstline = "^\\d{4}-\\d\\d-\\d\\dT"
    }

    stage.regex {
      expression = "^\\S+ \\[${ansi}(?P<detected_level>[a-z]+)${ansi}\\]"
    }
  }

  // [12:51:46 INF] Folder contents for music\... sent to user
  stage.match {
    selector = "{name=\"slskd\"}"

    stage.multiline {
      firstline = "^${ansi}\\[${ansi}\\d\\d:\\d\\d:\\d\\d"
    }

    stage.regex {
      expression = "^${ansi}\\[${ansi}\\d\\d:\\d\\d:\\d\\d${ansi} ${ansi}(?P<detected_level>[A-Z]{3})${ansi}\\]"
    }
  }

  // 2026-10-20T12:53:26Z INF HTTP duration="23.331µs" ip=10.42.0.10 method=GET path=/health status=200
  stage.match {
    selector = "{name=\"gotify\"}"

    stage.regex {
      expression = "^${ansi}\\S+${ansi} ${ansi}(?P<detected_level>[A-Z]{3})${ansi} "
    }
  }

  // 24:M 20 Oct 2026 12:50:23.143 * Background saving started, the symbol is the level:
  // . debug, - verbose, * notice, # warning
  stage.match {
    selector = "{name=~\".+-valkey\"}"

    stage.regex {
      expression = "^\\d+:[A-Z] \\d\\d \\w{3} \\d{4} \\d\\d:\\d\\d:\\d\\d\\.\\d{3} (?P<detected_level>[.*#-]) "
    }
  }

  // 2026-10-20 12:53:19.334 UTC [48] LOG:  checkpoint starting: time
  // DETAIL, HINT, STATEMENT and CONTEXT lines belong to the message before them
  stage.match {
    selector = "{name=~\".+-database\"}"

    stage.multiline {
      firstline = "^\\d{4}-\\d\\d-\\d\\d \\S+ \\S+ \\[\\d+\\] (?:LOG|INFO|NOTICE|WARNING|ERROR|FATAL|PANIC|DEBUG\\d?):"
    }

    stage.regex {
      expression = "^\\S+ \\S+ \\S+ \\[\\d+\\] (?P<detected_level>LOG|INFO|NOTICE|WARNING|ERROR|FATAL|PANIC|DEBUG)\\d?:"
    }
  }

  // {"level":"log","pid":24,"timestamp":1760000000000,"message":"...","context":"Api:StorageService"}
  stage.match {
    selector = "{name=\"immich\"}"

    stage.json {
      expressions = {
        detected_level = "level",
      }
    }
  }

  // [10/20/26 11:04:37] INFO     Application startup complete., rich wraps long messages
  stage.match {
    selector = "{name=\"immich-machine-learning\"}"

    stage.multiline {
      firstline = "^${ansi}\\[\\d\\d/\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d\\]"
    }

    stage.regex {
      expression = "^${ansi}\\[[\\d/ :]+\\]${ansi} ${ansi}(?P<detected_level>[A-Z]+)"
    }
  }

  // 2026-10-20T04:33:03.003+0900	INFO	running task	{"task": "backup for plan \"media-s3\""}
  stage.match {
    selector = "{name=\"backrest\"}"

    stage.regex {
      expression = "^\\S+\\t${ansi}(?P<detected_level>[A-Z]+)${ansi}\\t"
    }
  }

  // 2026-10-20T12:44:01.125692Z  INFO http.request{http.method=POST ...}: atuin_server::...
  stage.match {
    selector = "{name=\"atuin\"}"

    stage.multiline {
      firstline = "^${ansi}\\d{4}-\\d\\d-\\d\\dT"
    }

    stage.regex {
      expression = "^${ansi}\\S+Z${ansi}\\s+${ansi}\\s*(?P<detected_level>[A-Z]+)${ansi}"
    }
  }

  // INFO:     Uvicorn running on http://0.0.0.0:8080 (the run summaries are boxes without a level)
  stage.match {
    selector = "{name=\"qbitmanage\"}"

    stage.regex {
      expression = "^${ansi}(?P<detected_level>TRACE|DEBUG|INFO|WARNING|ERROR|CRITICAL)${ansi}:\\s"
    }
  }

  // 2026-10-19 16:04:02.088 [I] [http/middleware.go:35] http request: [/api/status]
  stage.match {
    selector = "{name=\"frpc\"}"

    stage.regex {
      expression = "^${ansi}\\S+ \\S+ \\[(?P<detected_level>[A-Z])\\] "
    }
  }

  // [Kavita] [2026-10-20 04:00:02.217 +09:00  64] [Information] Kavita.Services.ThemeService Sync Themes complete
  stage.match {
    selector = "{name=\"kavita\"}"

    stage.multiline {
      firstline = "^\\[Kavita\\] \\["
    }

    stage.regex {
      expression = "^\\[Kavita\\] \\[[^\\]]+\\] \\[(?P<detected_level>[A-Za-z]+)\\]"
    }
  }

  // WARN[220798] HTTP: GET http://navidrome.hosaka.cc/api/.env, logrus cuts the level to four letters
  stage.match {
    selector = "{name=\"navidrome\"}"

    stage.regex {
      expression = "^${ansi}(?P<detected_level>[A-Z]{4})${ansi}\\[\\d+\\]"
    }
  }

  // INFO[2026-10-20T00:00:03Z] job succeeded (supercronic) and [ERR] Config parsing failed (recyclarr),
  // the boxes recyclarr draws continue the line before them
  stage.match {
    selector = "{name=\"recyclarr\"}"

    stage.multiline {
      firstline = "^${ansi}(?:\\[|[A-Z]{4,5}${ansi}\\[)"
    }

    stage.regex {
      expression = "^${ansi}\\[${ansi}(?P<detected_level>[A-Z]{3})${ansi}\\]"
    }

    stage.regex {
      expression = "^${ansi}(?P<detected_level>[A-Z]{4,5})${ansi}\\[\\d{4}-"
    }
  }

  // [Info] RssSyncService: Starting RSS Sync, stack traces and indexer responses continue the line before them
  stage.match {
    selector = "{name=~\"lidarr|prowlarr|radarr|sonarr\"}"

    stage.multiline {
      firstline = "^${ansi}\\[(?:Trace|Debug|Info|Warn|Error|Fatal)\\] "
    }

    stage.regex {
      expression = "^${ansi}\\[(?P<detected_level>[A-Za-z]+)\\] "
    }
  }

  // [2026-10-20 22:05:03,748] [INFO] [paperless.classifier] No updates since last training
  // and celery's [2026-10-19 22:38:01,977: ERROR/MainProcess] Process 'ForkPoolWorker-365' exited
  stage.match {
    selector = "{name=\"paperless\"}"

    stage.multiline {
      firstline = "^${ansi}\\[\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d,\\d+"
    }

    stage.regex {
      expression = "^${ansi}\\[[^\\]]+\\] \\[(?P<detected_level>[A-Z]+)\\]"
    }

    stage.regex {
      expression = "^${ansi}\\[[^\\]]*: (?P<detected_level>[A-Z]+)/\\w+\\]"
    }
  }

  // [2026-10-20 22:05:46.766][vaultwarden::api::core::ciphers::_][WARN] Request guard `Headers` failed
  stage.match {
    selector = "{name=\"vaultwarden\"}"

    stage.multiline {
      firstline = "^\\[\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d"
    }

    stage.regex {
      expression = "^\\[[^\\]]+\\]\\[[^\\]]+\\]\\[(?P<detected_level>[A-Z]+)\\]"
    }
  }

  // mozlog, {"Timestamp":...,"Severity":6,"Fields":{...}}: 2 critical, 3 error, 4 warning, 6 info, 7 debug
  stage.match {
    selector = "{name=\"syncstorage\"}"

    stage.json {
      expressions = {
        detected_level = "Severity",
      }
    }

    // glean events carry no Severity
    stage.template {
      source   = "detected_level"
      template = "{{ default \"info\" .Value }}"
    }
  }

  // {"timestamp":"...","level":"Information",...} behind the keypad sequences .NET writes after running ffmpeg
  stage.match {
    selector = "{name=\"jellyfin\"}"

    stage.replace {
      expression = "^((?:\\x1b\\[\\?1h\\x1b=)+)"
      replace    = ""
    }
  }

  // 2026-10-20 10:58:18,708 WARNING:searx.network.brave: HTTP Request failed, tracebacks continue the line before them
  stage.match {
    selector = "{name=\"searxng\"}"

    stage.multiline {
      firstline = "^(?:\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d,\\d+ [A-Z]+:|\\[[A-Z]+\\] )"
    }
  }

  stage.template {
    source   = "detected_level"
    template = "{{ if .Value }}{{ $v := lower .Value }}{{ get (dict \"log\" \"info\" \"notice\" \"info\" \"*\" \"info\" \"#\" \"warn\" \"-\" \"debug\" \".\" \"debug\" \"i\" \"info\" \"w\" \"warn\" \"e\" \"error\" \"d\" \"debug\" \"t\" \"trace\" \"c\" \"critical\" \"f\" \"fatal\" \"vrb\" \"trace\" \"verbose\" \"trace\" \"ftl\" \"fatal\" \"pnc\" \"critical\" \"panic\" \"critical\" \"erro\" \"error\" \"debu\" \"debug\" \"trac\" \"trace\" \"fata\" \"fatal\" \"2\" \"critical\" \"3\" \"error\" \"4\" \"warn\" \"6\" \"info\" \"7\" \"debug\") $v | default $v }}{{ end }}"
  }

  stage.structured_metadata {
    values = {
      detected_level = "",
    }
  }
}

// IncusOS forwards ${node}'s journal here (systemd-netlogd, RFC 5424 over UDP).
loki.source.syslog "host" {
  listener {
    address                = "0.0.0.0:${syslog_port}"
    protocol               = "udp"
    use_incoming_timestamp = true

    labels = {
      location = "${node}",
      type     = "host",
    }
  }

  relabel_rules = loki.relabel.host.rules
  forward_to    = [loki.process.host.receiver]
}

// keep the program and severity of each message, e.g. app="Satellite", level="warn",
// with the syslog severities renamed to the levels Loki and Logs Drilldown know
loki.relabel "host" {
  forward_to = []

  rule {
    source_labels = ["__syslog_message_app_name"]
    target_label  = "app"
  }

  rule {
    source_labels = ["__syslog_message_severity"]
    target_label  = "level"
  }

  rule {
    source_labels = ["__syslog_message_severity"]
    regex         = "emergency|alert"
    target_label  = "level"
    replacement   = "critical"
  }

  rule {
    source_labels = ["__syslog_message_severity"]
    regex         = "warning"
    target_label  = "level"
    replacement   = "warn"
  }

  rule {
    source_labels = ["__syslog_message_severity"]
    regex         = "notice|informational"
    target_label  = "level"
    replacement   = "info"
  }
}

loki.process "host" {
  forward_to = [loki.write.loki.receiver]

  // the kernel audit trail is mostly syscall records from the node exporter and incusd,
  // only keep AppArmor denials and failed operations
  stage.match {
    selector = "{app=\"audit\"} !~ \"apparmor=.DENIED.|res=failed\""
    action   = "drop"
  }

  // systemd-gpt-auto-generator fails on every systemd reload, IncusOS' image policy doesn't allow partition auto-discovery
  stage.match {
    selector = "{app=~\"systemd-gpt-auto-generator|.sd-exec-\"} |~ \"does not match image policy|gpt-auto-generator failed\""
    action   = "drop"
  }

  // the LINSTOR satellite logs every storage pool poll, only keep its warnings and errors
  stage.match {
    selector = "{app=\"Satellite\", level=~\"info|debug\"}"
    action   = "drop"
  }
}

loki.write "loki" {
  endpoint {
    url = "${loki_url}"
  }
}
