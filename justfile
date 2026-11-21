#!/usr/bin/env just --justfile

import 'common.just'

[doc('list recipes (default)')]
@help:
    just --list --no-aliases

[doc('list recipes with submodules')]
@list:
    just --list --no-aliases --list-submodules

[arg('args', help='Recipe, or module and recipe, e.g. os reboot')]
[doc('show how to call a recipe')]
[no-exit-message]
@usage +args:
    just --usage {{ args }}

# cluster setup from scratch, one step at a time
mod bootstrap 'incus/bootstrap.just'

[arg('args', help='Passed to tofu init')]
[doc('initialize tofu with the S3 state backend, `just decrypt` first')]
init *args: (onpath 'tofu')
    prek install
    git config remote.origin.prune true
    tofu init -backend-config=state.s3.tfbackend {{ args }}

[arg('args', help='Passed to tofu validate')]
[doc('format, validate and lint the configuration')]
lint *args: (onpath 'tofu') (onpath 'git')
    git ls-files --cached --others --exclude-standard '*.tf' '*.tfvars' '*.tftest.hcl' \
      | xargs tofu fmt -check -diff
    tofu validate -lint=all {{ args }}

[arg('args', help='Passed to tofu plan')]
[arg('module', help='Module to plan, every one when empty')]
[doc('plan changes, optionally for one module')]
plan module='' *args: (onpath 'tofu')
    tofu plan {{ if module != '' { '-target=module.' + module } else { '' } }} {{ args }}

[arg('args', help='Passed to tofu apply')]
[arg('module', help='Module to apply, every one when empty')]
[doc('apply changes, optionally for one module')]
apply module='' *args: (onpath 'tofu')
    tofu apply {{ if module != '' { '-target=module.' + module } else { '' } }} {{ args }}

[arg('args', help='Passed to tofu destroy')]
[arg('module', help='Module to destroy')]
[doc('destroy the resources of a module')]
destroy module *args: (onpath 'tofu')
    tofu destroy -target=module.{{ module }} {{ args }}

# the VPS in front of the cluster
mod vps 'vps/vps.just'

# IncusOS management and automated updates
mod os 'incus/os.just'

# the public zone on deSEC
mod dns 'dns/dns.just'

[doc('follow logs of an instance')]
logs instance: (onpath 'incus')
    incus console --show-log {{ instance }}

[doc('stop an instance')]
stop instance: (onpath 'incus')
    incus stop {{ instance }}

[doc('restart an instance')]
restart instance: (onpath 'incus')
    incus restart {{ instance }}

[doc('delete cached images no instance was created from')]
prune: (onpath 'incus') (onpath 'jq')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}

    # Incus would expire them after 10 days, this frees the space now
    # projects without their own images use the default project's
    declare -A image_project
    while IFS=$'\t' read -r project own; do
      if [ "$own" = "true" ]; then image_project[$project]=$project; else image_project[$project]=default; fi
    done < <(incus project list -f json | jq -r '.[] | [.name, .config["features.images"] // "false"] | @tsv')

    declare -A used
    while IFS=, read -r project fingerprint; do
      if [ -n "$fingerprint" ]; then used["${image_project[$project]}/$fingerprint"]=1; fi
    done < <(incus list --all-projects -f csv -c e,config:volatile.base_image)

    # only images cached from a remote, imported and published ones never expire and stay
    prune=()
    total=0
    while IFS=$'\t' read -r project fingerprint size last_used source; do
      if [ -n "${used[$project/$fingerprint]:-}" ]; then continue; fi
      prune+=("$project $fingerprint")
      total=$((total + size))
      printf '%-9s %.12s %5s MiB  last used %s  %s\n' "$project" "$fingerprint" $((size / 1048576)) "$last_used" "$source"
    done < <(for project in $(printf '%s\n' "${image_project[@]}" | sort -u); do
      incus image list --project "$project" -f json | jq -r --arg project "$project" \
        '.[] | select(.cached) | [$project, .fingerprint, .size, .last_used_at[0:10], .update_source.alias // ""] | @tsv'
    done | sort -t $'\t' -k5,5)

    if [ ${#prune[@]} -eq 0 ]; then
      success "no unused images"
      exit 0
    fi

    yono "delete these ${#prune[@]} images ($((total / 1048576)) MiB)?" || exit 1

    for entry in "${prune[@]}"; do
      read -r project fingerprint <<<"$entry"
      incus image delete --project "$project" "$fingerprint"
    done
    success "deleted ${#prune[@]} images"

# restores from the backups
mod backup 'backups/backup.just'

[arg('files', help='Plaintext files or their .age copies, by default every plaintext edited since it was decrypted')]
[doc('encrypt files to the YubiKeys in recipients.txt')]
[positional-arguments]
encrypt *files: (onpath 'age') (onpath 'git')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}

    if [ $# -gt 0 ]; then
      files=("${@%.age}")
    else
      mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.age' | sed 's/\.age$//')
    fi

    # encrypt and decrypt copy the modification time over, equal times mean the two are in sync
    for f in "${files[@]}"; do
      if [ $# -eq 0 ]; then
        # not decrypted in this clone, or state.key which never is
        if [ ! -e "$f" ]; then continue; fi
        # a newer version came in with git that isn't decrypted yet, encrypting would undo it
        if [ "$f.age" -nt "$f" ]; then warning "skipped $f: $f.age is newer, decrypt it first"; continue; fi
        if [ ! "$f" -nt "$f.age" ]; then continue; fi
      fi
      if ! git check-ignore -q "$f"; then
        error "$f is not ignored by git, add it to .gitignore before encrypting it"
      fi
      age --encrypt --recipients-file recipients.txt --output "$f.age" "$f"
      touch -r "$f" "$f.age"
      info "encrypted $f"
    done

[arg('files', help='Plaintext files or their .age copies, by default every .age file newer than its plaintext')]
[doc('decrypt .age files with a plugged in YubiKey')]
[positional-arguments]
decrypt *files: (onpath 'age') (onpath 'age-plugin-yubikey') (onpath 'git')
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077
    {{ logger }}

    if [ $# -gt 0 ]; then
      files=("${@%.age}")
    else
      mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.age' | sed 's/\.age$//')
    fi

    identities=$(age-plugin-yubikey --identity 2>/dev/null)
    if [[ $identities != *AGE-PLUGIN-YUBIKEY-* ]]; then error "no YubiKey with an age identity is plugged in"; fi

    for f in "${files[@]}"; do
      # only state.key.sh decrypts it, and never to disk
      if [ "$f" = state.key ]; then continue; fi
      if [ $# -eq 0 ] && [ -e "$f" ]; then
        if [ "$f" -nt "$f.age" ]; then warning "skipped $f: it has changes, encrypt it first"; continue; fi
        if [ ! "$f.age" -nt "$f" ]; then continue; fi
      fi
      age --decrypt --identity - --output "$f" "$f.age" <<<"$identities"
      touch -r "$f.age" "$f"
      info "decrypted $f"
    done

# values for new services, OIDC clients and users, and new YubiKeys
mod new 'new.just'
