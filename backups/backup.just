# Works with the restic repositories Backrest backs up to.

import '../common.just'

[doc('list recipes (default)')]
@help:
    just --justfile {{ quote(justfile()) }} --list backup --unsorted --no-aliases

[arg('volume', help='Volume to restore, e.g. gotify-data')]
[arg('snapshot', help='Snapshot ID from the Backrest UI, or latest')]
[doc('overwrite a volume with a snapshot from the nas repo')]
restore volume snapshot: (onpath 'incus')
    incus exec -t backrest -- restore-volume {{ volume }} {{ snapshot }}
