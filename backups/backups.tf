locals {
  backrest_ports = {
    webui = 9898
  }

  data_path  = "/var/lib/backrest" # run history, restic's cache and the Incus client
  apps_path  = "/source/apps"      # mount-clones attaches each volume's clone under here
  dumps_path = "/var/lib/backup/db"
  nas_repo   = "/repos/nas"

  incus_conf   = "/etc/incus"
  nas_password = "/etc/backrest/nas.password"

  volumes   = merge([for s in var.sources : s.volumes]...)
  databases = distinct(flatten([for s in var.sources : s.databases]))

  # common patterns to exclude
  apps_excludes = concat(
    ["*.db-shm", "*.pid", "*.log", "logs", "log", "cache", ".cache"],
    flatten([for name, v in local.volumes : [for e in v.excludes : "${local.apps_path}/${name}/${e}"]]),
  )

  retention = {
    nas = { policyTimeBucketed = { daily = 7, weekly = 4, monthly = 6 } }
  }

  hooks = {
    mount_clones = {
      conditions    = ["CONDITION_SNAPSHOT_START"]
      onError       = "ON_ERROR_CANCEL"
      actionCommand = { command = "/usr/local/bin/mount-clones" }
    }
    unmount_clones = {
      conditions    = ["CONDITION_SNAPSHOT_END", "CONDITION_SNAPSHOT_ERROR"]
      actionCommand = { command = "/usr/local/bin/unmount-clones" }
    }
    dump_databases = {
      conditions    = ["CONDITION_SNAPSHOT_START"]
      onError       = "ON_ERROR_CANCEL"
      actionCommand = { command = "/usr/local/bin/dump-databases" }
    }
  }

  # Backrest rewrites this file, so changes made in the UI will be lost
  backrest_config = jsonencode({
    version  = 6
    instance = "cluster"

    repos = [
      {
        id          = "nas"
        uri         = local.nas_repo
        guid        = random_id.nas_repo.hex
        env         = ["RESTIC_PASSWORD_FILE=${local.nas_password}"]
        autoUnlock  = true
        prunePolicy = { schedule = { cron = "0 3 * * 0" }, maxUnusedPercent = 10 }
        checkPolicy = { schedule = { cron = "30 3 * * 0" }, structureOnly = true }
      },
    ]

    plans = [
      {
        id        = "databases-nas"
        repo      = "nas"
        paths     = [local.dumps_path]
        schedule  = { cron = "0 2 * * *" }
        retention = local.retention.nas
        hooks     = [local.hooks.dump_databases]
      },
      {
        id        = "apps-nas"
        repo      = "nas"
        paths     = [local.apps_path]
        excludes  = local.apps_excludes
        schedule  = { cron = "0 2 * * *" }
        retention = local.retention.nas
        hooks     = [local.hooks.mount_clones, local.hooks.unmount_clones]
      },
    ]

    auth = {
      users = [{ name = var.secrets.username, passwordBcrypt = var.secrets.password_bcrypt }]
    }
  })

  start_script = templatefile("${path.module}/start.sh.tpl", {
    wait_for = [
      "/config/config.json",
      local.nas_password,
      "${local.incus_conf}/config.yml",
      "${local.incus_conf}/client.crt",
      "${local.incus_conf}/client.key",
      "${local.incus_conf}/servercerts/cluster.crt",
    ]
    data_path     = local.data_path
    incus_version = var.versions.incus
    incus_sha256  = var.versions.incus_sha256
    nas_repo      = local.nas_repo
    nas_password  = local.nas_password
  })

  hook_scripts = {
    mount-clones = templatefile("${path.module}/mount-clones.sh.tpl", {
      instance  = "backrest"
      volumes   = keys(local.volumes)
      apps_path = local.apps_path
    })
    unmount-clones = templatefile("${path.module}/unmount-clones.sh.tpl", {
      instance = "backrest"
      volumes  = keys(local.volumes)
    })
    dump-databases = templatefile("${path.module}/dump-databases.sh.tpl", {
      databases  = local.databases
      dumps_path = local.dumps_path
    })
  }

  incus_config = yamlencode({
    default-remote = "cluster"
    remotes = {
      cluster = {
        addr      = var.cluster_address
        auth_type = "tls"
        project   = "default"
        protocol  = "incus"
        public    = false
      }
    }
  })
}

# Repository id. It's normally restic's repository id, but nothing checks that they match,
# and setting it up front avoids backrest attempting to initialize it, which rewrites the config.
resource "random_id" "nas_repo" {
  byte_length = 32
}

resource "incus_certificate" "backup" {
  name        = "backup"
  type        = "client"
  description = "Backrest hooks, snapshots, clones and database dumps"
  certificate = file("${path.module}/backup.crt")
  restricted  = true
  projects    = ["default"]
}

resource "incus_storage_volume" "backrest_data" {
  name   = "backrest-data"
  pool   = "local"
  target = var.target
}

resource "incus_storage_volume" "restic" {
  name         = "restic"
  description  = "Restic repository for LINSTOR data"
  pool         = var.restic_pool
  target       = var.target
  type         = "custom"
  content_type = "filesystem"

  config = {
    # pack files (16 MiB) are written once, but restores and prune read single blobs out of them,
    # so larger records than 1 MiB would mostly add read amplification
    "zfs.blocksize" = "1MiB"
  }
}

resource "incus_instance" "backrest" {
  name = "backrest"
  type = "container"

  target   = var.target
  profiles = ["default", "mesh"]
  image    = "ghcr:garethgeorge/backrest:v${var.versions.backrest}"

  file {
    content            = local.start_script
    target_path        = "/usr/local/bin/backrest-start"
    mode               = "0755"
    create_directories = true
  }

  file {
    content            = sensitive(local.backrest_config)
    target_path        = "/config/config.json"
    mode               = "0600"
    create_directories = true
  }

  file {
    content            = sensitive(var.secrets.restic_password_nas)
    target_path        = local.nas_password
    mode               = "0600"
    create_directories = true
  }

  dynamic "file" {
    for_each = local.hook_scripts

    content {
      content            = file.value
      target_path        = "/usr/local/bin/${file.key}"
      mode               = "0755"
      create_directories = true
    }
  }

  file {
    content            = local.incus_config
    target_path        = "${local.incus_conf}/config.yml"
    mode               = "0644"
    create_directories = true
  }

  file {
    content            = var.cluster_certificate
    target_path        = "${local.incus_conf}/servercerts/cluster.crt"
    mode               = "0644"
    create_directories = true
  }

  file {
    content            = file("${path.module}/backup.crt")
    target_path        = "${local.incus_conf}/client.crt"
    mode               = "0644"
    create_directories = true
  }

  file {
    content            = sensitive(file("${path.module}/backup.key"))
    target_path        = "${local.incus_conf}/client.key"
    mode               = "0600"
    create_directories = true
  }

  device {
    name = "data"
    type = "disk"
    properties = {
      path   = local.data_path
      pool   = incus_storage_volume.backrest_data.pool
      source = incus_storage_volume.backrest_data.name
    }
  }

  device {
    name = "restic"
    type = "disk"
    properties = {
      path   = local.nas_repo
      pool   = incus_storage_volume.restic.pool
      source = incus_storage_volume.restic.name
    }
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    # files are pushed after the start, backrest-start waits for the rest of them
    "oci.entrypoint" = "/bin/sh -c 'while [ ! -x /usr/local/bin/backrest-start ]; do sleep 1; done; exec /usr/local/bin/backrest-start'"

    "environment.TZ"             = var.timezone
    "environment.BACKREST_DATA"  = "${local.data_path}/data"
    "environment.XDG_CACHE_HOME" = "${local.data_path}/cache"
    "environment.INCUS_CONF"     = local.incus_conf

    "user.access_interface" = "eth1"
  }

  depends_on = [incus_certificate.backup]
}

resource "null_resource" "backrest_restart" {
  triggers = {
    config = nonsensitive(sha1(local.backrest_config))
    start  = sha1(local.start_script)
  }

  provisioner "local-exec" {
    command = "incus restart ${incus_instance.backrest.name}"
  }
}

output "probes" {
  value = [
    "https://backup.${var.private_domain}/",
  ]
}

output "ingress" {
  value = {
    name  = "backup"
    caddy = <<-EOT
			backup.${var.private_domain} {
				reverse_proxy ${incus_instance.backrest.ipv4_address}:${local.backrest_ports.webui}
			}
    EOT
  }
}
