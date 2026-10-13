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

// keep the program and severity of each message, e.g. app="Satellite", level="warning"
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
    selector = "{app=\"Satellite\", level=~\"informational|notice|debug\"}"
    action   = "drop"
  }
}

loki.write "loki" {
  endpoint {
    url = "${loki_url}"
  }
}
