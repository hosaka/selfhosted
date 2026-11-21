# The public DNS zone for the cluster.

import '../common.just'

# tofu console reads the configuration in the repository root
set working-directory := '..'

[doc('show the public zone as deSEC serves it (default)')]
status: (onpath 'tofu') (onpath 'curl')
    #!/usr/bin/env bash
    set -euo pipefail

    # the token goes from tofu straight into curl's headers and is never printed
    read -r domain token < <(tofu console -lock=false <<<'"${var.public_domain} ${var.secrets.dns.desec_token}"' | tr -d '"')
    curl -sS --fail-with-body -H @- "https://desec.io/api/v1/domains/$domain/zonefile/" <<<"Authorization: Token $token"

[doc('list recipes')]
@help:
    just --justfile {{ quote(justfile()) }} --list dns --unsorted --no-aliases
