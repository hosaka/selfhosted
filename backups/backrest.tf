locals {
  backrest_ports = {
    webui = 9898
  }

  data_path    = "/var/lib/backrest" # run history, restic's cache and the Incus client
  apps_path    = "/source/apps"      # mount-clones attaches each volume's clone under here
  restore_path = "/restore"          # restore-volume attaches the volume it restores under here
  dumps_path   = "/var/lib/backup/db"
  nas_path     = "/source" # the nas pool's volumes are attached read-only under here
  nas_repo     = "/repos/nas"

  incus_conf      = "/etc/incus"
  restic_password = "/etc/backrest/restic.password" # both repos share it, but could be different

  # common patterns to exclude
  excludes = ["*.db-shm", "*.pid", "*.log", "logs", "log", "cache", ".cache"]

  volumes = merge([for app, s in var.sources : s.volumes]...)

  # tasks run one at a time, so the s3 plans start once the nas plans are done
  repos = {
    nas = { schedule = "0 2 * * *", retention = { policyTimeBucketed = { daily = 7, weekly = 4, monthly = 6 } } }
    s3  = { schedule = "0 4 * * *", retention = { policyTimeBucketed = { daily = 7, weekly = 4, monthly = 12 } } }
  }

  # Repo hooks, so they fire for every plan's backups and forgets as well as the repo's prune and check.
  # A hook that fails to send is only logged, it doesn't fail the task.
  notifications = [
    {
      # failed tasks, including a hook that cancelled a backup
      conditions = ["CONDITION_ANY_ERROR"]
      actionGotify = {
        baseUrl       = var.gotify_address
        token         = var.secrets.gotify_token
        titleTemplate = "{{ .Task }} failed"
        template      = "{{ .Error }}"
        priority      = 8
      }
    },
    {
      # backups that skipped files restic couldn't read
      conditions = ["CONDITION_SNAPSHOT_WARNING"]
      actionGotify = {
        baseUrl       = var.gotify_address
        token         = var.secrets.gotify_token
        titleTemplate = "{{ .Task }} incomplete"
        template      = "{{ .Error }}"
        priority      = 5
      }
    },
  ]

  # one plan per application and repo, these go to nas and an s3 bucket
  plans = {
    for app, s in var.sources : app => {
      paths = concat(
        [for v in keys(s.volumes) : "${local.apps_path}/${v}"],
        [for db in s.databases : "${local.dumps_path}/${db}.sql"],
      )
      excludes = concat(local.excludes, flatten([
        for v, c in s.volumes : [for e in c.excludes : "${local.apps_path}/${v}/${e}"]
      ]))
      hooks = concat(
        length(s.databases) > 0 ? [{
          conditions    = ["CONDITION_SNAPSHOT_START"]
          onError       = "ON_ERROR_CANCEL"
          actionCommand = { command = "/usr/local/bin/dump-databases ${join(" ", s.databases)}" }
        }] : [],
        [
          {
            conditions    = ["CONDITION_SNAPSHOT_START"]
            onError       = "ON_ERROR_CANCEL"
            actionCommand = { command = "/usr/local/bin/mount-clones ${join(" ", keys(s.volumes))}" }
          },
          {
            conditions    = ["CONDITION_SNAPSHOT_END", "CONDITION_SNAPSHOT_ERROR"]
            actionCommand = { command = "/usr/local/bin/unmount-clones ${join(" ", keys(s.volumes))}" }
          },
        ],
      )
    }
  }

  # one plan per nas pool volume, these only go to an s3 bucket
  nas_plans = {
    for name, n in var.nas_sources : name => {
      paths    = [for p in n.paths : trimsuffix("${local.nas_path}/${n.volume}/${p}", "/")]
      excludes = [for e in n.excludes : "${local.nas_path}/${n.volume}/${e}"]
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
        env         = ["RESTIC_PASSWORD_FILE=${local.restic_password}"]
        autoUnlock  = true
        prunePolicy = { schedule = { cron = "0 3 * * 0" }, maxUnusedPercent = 10 }
        checkPolicy = { schedule = { cron = "30 3 * * 0" }, structureOnly = true }
        hooks       = local.notifications
      },
      {
        id   = "s3"
        uri  = var.secrets.s3_repository
        guid = random_id.s3_repo.hex
        env = [
          "RESTIC_PASSWORD_FILE=${local.restic_password}",
          "AWS_ACCESS_KEY_ID=${var.secrets.s3_access_key_id}",
          "AWS_SECRET_ACCESS_KEY=${var.secrets.s3_secret_access_key}",
        ]
        autoUnlock = true
        # every three months on the 1st at 05:00, backups are prunned
        prunePolicy = { schedule = { cron = "0 5 1 */3 *" }, maxUnusedPercent = 10 }
        # each month on the 15th at 05:00, a random 5% of backups are downloaded and verified
        checkPolicy = { schedule = { cron = "0 5 15 * *" }, readDataSubsetPercent = 5 }
        hooks       = local.notifications
      },
    ]

    plans = concat(
      flatten([
        for repo, r in local.repos : [
          for app, p in local.plans : {
            id        = "${app}-${repo}"
            repo      = repo
            paths     = p.paths
            excludes  = p.excludes
            schedule  = { cron = r.schedule }
            retention = r.retention
            hooks     = p.hooks
          }
        ]
      ]),
      [
        for name, p in local.nas_plans : {
          id        = "${name}-s3"
          repo      = "s3"
          paths     = p.paths
          excludes  = p.excludes
          schedule  = { cron = "30 4 * * *" }
          retention = local.repos.s3.retention
          hooks     = []
        }
      ],
    )

    auth = {
      users = [{ name = var.secrets.backrest_username, passwordBcrypt = var.secrets.backrest_password_bcrypt }]
    }
  })

  start_script = templatefile("${path.module}/start.sh.tpl", {
    wait_for = [
      "/config/config.json",
      local.restic_password,
      "${local.incus_conf}/config.yml",
      "${local.incus_conf}/client.crt",
      "${local.incus_conf}/client.key",
      "${local.incus_conf}/servercerts/cluster.crt",
    ]
    data_path       = local.data_path
    incus_version   = var.versions.incus
    incus_sha256    = var.versions.incus_sha256
    nas_repo        = local.nas_repo
    restic_password = local.restic_password
  })

  scripts = {
    mount-clones = templatefile("${path.module}/mount-clones.sh.tpl", {
      instance  = "backrest"
      apps_path = local.apps_path
    })
    unmount-clones = templatefile("${path.module}/unmount-clones.sh.tpl", {
      instance = "backrest"
    })
    dump-databases = templatefile("${path.module}/dump-databases.sh.tpl", {
      dumps_path = local.dumps_path
    })
    restore-volume = templatefile("${path.module}/restore-volume.sh.tpl", {
      instance        = "backrest"
      apps_path       = local.apps_path
      restore_path    = local.restore_path
      nas_repo        = local.nas_repo
      restic_password = local.restic_password
      excludes        = local.excludes
      # anchored at the volume's root
      volumes = { for v, c in local.volumes : v => [for e in c.excludes : "/${e}"] }
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

# Repository ids. They're normally restic's repository ids, but nothing checks that they match,
# and setting them up front avoids backrest attempting to initialize the repos, which rewrites the config.
resource "random_id" "nas_repo" {
  byte_length = 32
}

resource "random_id" "s3_repo" {
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
  profiles = ["default", "oci"]
  image    = "ghcr:garethgeorge/backrest:v${var.versions.backrest}"

  device {
    name       = "eth0"
    type       = "nic"
    properties = var.addresses.backrest.nic
  }

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
    content            = sensitive(var.secrets.restic_password)
    target_path        = local.restic_password
    mode               = "0600"
    create_directories = true
  }

  dynamic "file" {
    for_each = local.scripts

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

  dynamic "device" {
    for_each = { for n in values(var.nas_sources) : n.volume => n.pool }

    content {
      name = "nas-${device.key}"
      type = "disk"
      properties = {
        path     = "${local.nas_path}/${device.key}"
        pool     = device.value
        source   = device.key
        readonly = "true"
      }
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
  }

  lifecycle {
    # backrest refuses a config with two plans of the same id
    precondition {
      condition     = length(setintersection(keys(var.sources), keys(var.nas_sources))) == 0
      error_message = "nas_sources and sources share names: ${join(", ", setintersection(keys(var.sources), keys(var.nas_sources)))}"
    }
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
