#!/usr/bin/env just --justfile

cwd := quote(invocation_directory() + "/")

[doc('list recipes (default)')]
@help:
    just --list --no-aliases

[doc('list recipes with submodules')]
@list:
    just --list --no-aliases --list-submodules

[doc('show a recipe usage')]
[no-exit-message]
@usage +args:
    just --usage {{ args }}

[private]
@onpath tool:
    echo 'using {{ require(tool) }}' > /dev/null

[arg('what', pattern='image|cluster|server|linstor', help='image <node> [img|iso]: an IncusOS image for one node, cluster: form the cluster from var.cluster, server [tofu args]: the base resources, linstor: storage pools and linstor')]
[doc('set up the cluster from scratch, one step at a time')]
bootstrap what *args:
    @just _bootstrap-{{ what }} {{ args }}

[arg('format', pattern='iso|img', help='File format to generate')]
[doc('prepare images for all nodes in incus/')]
images format='img':
    #!/usr/bin/env bash
    set -euo pipefail

    for dir in incus/node-*/; do
      just _bootstrap-image "$(basename "$dir")" {{ format }}
    done

[arg('format', pattern='iso|img', help='File format to generate')]
[arg('node', help='Node to build the image for, a directory in incus/ with its seed files')]
_bootstrap-image node format='img': _flasher-tool (onpath 'tar')
    #!/usr/bin/env bash
    set -euo pipefail

    if [ ! -d incus/{{ quote(node) }} ]; then
      echo "incus/{{ node }}/ doesn't exist, nodes are: $(cd incus && echo node-*)" >&2
      exit 1
    fi

    apps=incus
    if [ -f incus/{{ node }}/applications.yml ]; then
      apps=incus/{{ node }}
    fi

    tar -cvf seed-{{ node }}.tar --directory=incus/ incus.yml update.yml
    tar -rvf seed-{{ node }}.tar --directory="$apps"/ applications.yml
    tar -rvf seed-{{ node }}.tar --directory=incus/{{ node }}/ install.yml network.yml services.yml
    flasher-tool --channel=stable --format={{ format }} --seed=seed-{{ node }}.tar
    mv IncusOS_*.{{ format }} incus-os-{{ node }}.{{ format }}
    rm seed-{{ node }}.tar

[arg('target', pattern='/dev/.*', help='Path to IncusOS image')]
[arg('image', pattern='.*\.img|.*\.iso', help='Target block device')]
[doc('flash an IncusOS image to a target device')]
flash image target:
    doas dd bs=4M if={{ image }} of={{ target }} status=progress oflag=sync

[private]
_flasher-tool: (onpath 'go')
    go install github.com/lxc/incus-os/incus-osd/cmd/flasher-tool@latest

_bootstrap-cluster: (onpath 'incus') (onpath 'tofu')
    #!/usr/bin/env bash
    set -euo pipefail

    # the cluster name, the founding nodes' names and addresses from var.cluster
    read -r name node1 ip1 node2 ip2 node3 ip3 < <(tofu console -lock=false <<'EOF' | tr -d '"'
    join(" ", [var.cluster.name, var.cluster.node-1.target, var.cluster.node-1.ipv4_address, var.cluster.node-2.target, var.cluster.node-2.ipv4_address, var.cluster.node-3.target, var.cluster.node-3.ipv4_address])
    EOF
    ) || true
    if [ -z "${ip3:-}" ]; then
      echo "couldn't read var.cluster, decrypt and init first" >&2
      exit 1
    fi
    set -x

    # add individual nodes first
    incus remote add "$node1" "$ip1"
    incus remote add "$node2" "$ip2"
    incus remote add "$node3" "$ip3"
    # enable cluster and set it as default
    incus config set "$node1": cluster.https_address="$ip1":8443
    incus cluster enable "$node1": "$node1"
    incus remote add "$name" "$ip1"
    incus remote switch "$name"
    # join the remaining nodes
    incus cluster join "$name": "$node2":
    incus cluster join "$name": "$node3":
    # remove individual nodes
    incus remote remove "$node1"
    incus remote remove "$node2"
    incus remote remove "$node3"

_bootstrap-server *args: (onpath 'tofu')
    tofu apply -target=null_resource.post_server {{ args }}

_bootstrap-linstor: (onpath 'incus') (onpath 'tofu') (onpath 'yq')
    #!/usr/bin/env bash
    set -euo pipefail

    NODES=(node-1 node-2 node-3)

    declare -A disks

    for node in "${NODES[@]}"; do
      show=$(incus admin os system storage show --target "$node")

      if echo "$show" | yq -e '.state.pools[] | select(.name == "nvme")' >/dev/null 2>&1; then
        echo "$node: nvme pool already exists, skipping"
        continue
      fi

      mapfile -t free < <(echo "$show" | yq -r '
        .state.drives[]
        | select((.member_pool // "") == "")
        | select(.boot != true)
        | .id')

      case ${#free[@]} in
        0)
          echo "$node: no unallocated drives" >&2
          exit 1
          ;;
        1)
          disks[$node]="${free[0]}"
          ;;
        *)
          echo "$node:"
          printf '%s\n' "${free[@]}" | nl -w2 -s') '
          while :; do
            read -rp "select drive for $node [1-${#free[@]}]: " n
            if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#free[@]} )); then
              disks[$node]="${free[$((n-1))]}"
              break
            fi
          done
          ;;
      esac
    done

    if [ -n "${disks[*]:-}" ]; then
      for node in "${NODES[@]}"; do
        if [ -n "${disks[$node]:-}" ]; then echo "$node: ${disks[$node]}"; fi
      done
      read -rp "wipe these drives and use them for linstor pool (double check the drive ids)? [y/N] " ok
      [ "$ok" = "y" ] || exit 1

      for node in "${NODES[@]}"; do
        [ -n "${disks[$node]:-}" ] || continue

        # wipe the drives beforehand (if a ZFS volume already exists, creating one will fail)
        incus admin os system storage wipe-drive -d "{\"id\":\"${disks[$node]}\"}" --target "$node"

        # make sure the linstor service is enabled in incus
        incus admin os service show linstor --target "$node" \
          | yq '.config.enabled = true' \
          | incus admin os service edit linstor --target "$node"

        # create a ZFS pool with devices
        incus admin os system storage show --target "$node" \
          | yq ".config.pools = ((.config.pools // []) | map(select(.name != \"nvme\")) + [{\"name\":\"nvme\",\"type\":\"zfs-raid0\",\"devices\":[\"${disks[$node]}\"]}])" \
          | incus admin os system storage edit --target "$node"

        # create a ZFS volume on top of the pool that will be used by linstor
        incus admin os system storage create-volume -d '{"pool":"nvme","name":"linstor","use":"linstor"}' --target "$node" || true
      done
    fi

    tofu apply -auto-approve -target=module.linstor.null_resource.post_linstor_controller

    for node in "${NODES[@]}"; do
      incus exec --project=internal linstor-controller -- linstor storage-pool create zfsthin "$node" nvme nvme/linstor || true
    done

    tofu apply -auto-approve -target=module.linstor.null_resource.post_linstor

[doc('initialize tofu with the S3 state backend, decrypt state.s3.tfbackend first')]
init *args: (onpath 'tofu')
    prek install
    git config remote.origin.prune true
    tofu init -backend-config=state.s3.tfbackend {{ args }}

[doc('format, validate and lint the configuration')]
lint *args: (onpath 'tofu') (onpath 'git')
    git ls-files --cached --others --exclude-standard '*.tf' '*.tfvars' '*.tftest.hcl' \
      | xargs tofu fmt -check -diff
    tofu validate -lint=all {{ args }}

[doc('plan changes, optionally for one module')]
plan module='' *args: (onpath 'tofu')
    tofu plan {{ if module != '' { '-target=module.' + module } else { '' } }} {{ args }}

[doc('apply changes, optionally for one module')]
apply module='' *args: (onpath 'tofu')
    tofu apply {{ if module != '' { '-target=module.' + module } else { '' } }} {{ args }}

[doc('destroy module changes')]
destroy module *args: (onpath 'tofu')
    tofu destroy -target=module.{{ module }} {{ args }}

[arg('what', pattern='diff|deploy', help='diff: show what deploying would change, deploy: deploy, asks before changing anything')]
[doc('show or deploy changes to the VPS')]
vps what *args:
    @just _vps-{{ what }} {{ args }}

_vps-diff *args: (onpath 'uv')
    uv run pyinfra --chdir vps inventory.py deploy.py --dry --diff {{ args }}

_vps-deploy *args: (onpath 'uv')
    uv run pyinfra --chdir vps inventory.py deploy.py --diff {{ args }}

[arg('what', pattern='dns', help='What to show: dns is the public zone as deSEC serves it')]
[doc('show live state from outside services')]
show what: (onpath 'tofu') (onpath 'curl')
    #!/usr/bin/env bash
    set -euo pipefail

    # the token goes from tofu straight into curl's headers and is never printed
    read -r domain token < <(tofu console -lock=false <<<'"${var.public_domain} ${var.secrets.dns.desec_token}"' | tr -d '"')
    curl -sS --fail-with-body -H @- "https://desec.io/api/v1/domains/$domain/zonefile/" <<<"Authorization: Token $token"

[doc('follow logs of an instance')]
logs instance: (onpath 'incus')
    incus console --show-log {{ instance }}

[doc('bring an instance down')]
stop instance: (onpath 'incus')
    incus stop {{ instance }}

[doc('restart an instance')]
restart instance: (onpath 'incus')
    incus restart {{ instance }}

[doc('delete cached images no instance was created from, Incus would expire them after 10 days')]
prune: (onpath 'incus') (onpath 'jq')
    #!/usr/bin/env bash
    set -euo pipefail

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
      echo "no unused images"
      exit 0
    fi

    read -rp "delete these ${#prune[@]} images ($((total / 1048576)) MiB)? [y/N] " ok
    [ "$ok" = "y" ] || exit 1

    for entry in "${prune[@]}"; do
      read -r project fingerprint <<<"$entry"
      incus image delete --project "$project" "$fingerprint"
    done
    echo "deleted ${#prune[@]} images"

[arg('what', pattern='restore', help='restore <volume> <snapshot ID|latest>: restore a volume in place from the nas repo, replacing its contents (destructive)')]
[doc('work with the backups')]
backup what *args:
    @just _backup-{{ what }} {{ args }}

[arg('volume', help='Volume to restore, e.g. gotify-data')]
[arg('snapshot', help='Snapshot ID from the Backrest UI, or latest')]
_backup-restore volume snapshot: (onpath 'incus')
    incus exec -t backrest -- restore-volume {{ volume }} {{ snapshot }}

[arg('files', help='Plaintext files or their .age copies, every .age file in the repo by default')]
[doc('encrypt files to the YubiKeys in recipients.txt as <file>.age, by default the ones changed since')]
[positional-arguments]
encrypt *files: (onpath 'age') (onpath 'git')
    #!/usr/bin/env bash
    set -euo pipefail

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
        if [ "$f.age" -nt "$f" ]; then echo "skipped $f: $f.age is newer, decrypt it first" >&2; continue; fi
        if [ ! "$f" -nt "$f.age" ]; then continue; fi
      fi
      if ! git check-ignore -q "$f"; then
        echo "$f is not ignored by git, add it to .gitignore before encrypting it" >&2
        exit 1
      fi
      age --encrypt --recipients-file recipients.txt --output "$f.age" "$f"
      touch -r "$f" "$f.age"
      echo "encrypted $f"
    done

[arg('files', help='Plaintext files or their .age copies, every .age file in the repo by default')]
[doc('decrypt <file>.age files with a connected YubiKey, by default the ones changed since')]
[positional-arguments]
decrypt *files: (onpath 'age') (onpath 'age-plugin-yubikey') (onpath 'git')
    #!/usr/bin/env bash
    set -euo pipefail
    umask 077

    if [ $# -gt 0 ]; then
      files=("${@%.age}")
    else
      mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.age' | sed 's/\.age$//')
    fi

    identities=$(age-plugin-yubikey --identity 2>/dev/null)
    if [[ $identities != *AGE-PLUGIN-YUBIKEY-* ]]; then echo "no YubiKey with an age identity is plugged in" >&2; exit 1; fi

    for f in "${files[@]}"; do
      # only state.key.sh decrypts it, and never to disk
      if [ "$f" = state.key ]; then continue; fi
      if [ $# -eq 0 ] && [ -e "$f" ]; then
        if [ "$f" -nt "$f.age" ]; then echo "skipped $f: it has changes, encrypt it first" >&2; continue; fi
        if [ ! "$f.age" -nt "$f" ]; then continue; fi
      fi
      age --decrypt --identity - --output "$f" "$f.age" <<<"$identities"
      touch -r "$f.age" "$f"
      echo "decrypted $f"
    done

[doc('re-encrypt every .age file to recipients.txt, after adding or removing a YubiKey')]
rekey: (onpath 'age') (onpath 'age-plugin-yubikey') (onpath 'git')
    #!/usr/bin/env bash
    set -euo pipefail

    mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.age')
    identities=$(age-plugin-yubikey --identity 2>/dev/null)
    if [[ $identities != *AGE-PLUGIN-YUBIKEY-* ]]; then echo "no YubiKey with an age identity is plugged in" >&2; exit 1; fi

    for f in "${files[@]}"; do
      # from one age straight into the other, the plaintext never touches the disk
      age --decrypt --identity - "$f" <<<"$identities" \
        | age --encrypt --recipients-file recipients.txt --output "$f.tmp"
      # keep the modification time, encrypt and decrypt compare it with the plaintext's
      touch -r "$f" "$f.tmp"
      mv "$f.tmp" "$f"
      echo "re-encrypted $f"
    done

[doc('generate the passphrase state and plan files are encrypted with (state.tf), only needed once')]
state-key: (onpath 'age') (onpath 'openssl')
    #!/usr/bin/env bash
    set -euo pipefail

    # a new passphrase can't decrypt the existing state
    if [ -e state.key.age ]; then
      echo "state.key.age already exists, replacing it would make the state unreadable" >&2
      exit 1
    fi

    # piped straight into age, the passphrase is never shown or written to disk
    openssl rand -base64 48 | tr -d '\n' | age --encrypt --recipients-file recipients.txt --output state.key.age
    echo "created state.key.age"

[arg('what', pattern='service|oidc', help='service [name]: a free OVN address and MAC for addresses.auto.tfvars, oidc: an OIDC client id and secret')]
[doc('generate values for a new service or OIDC client')]
new what *args:
    @just _new-{{ what }} {{ args }}

_new-service name='service': (onpath 'tofu') (onpath 'openssl') (onpath 'git')
    #!/usr/bin/env bash
    set -euo pipefail

    # the lowest free address in the static range: from .10 up to where the DHCP range starts
    ipv4=$(tofu console -lock=false <<'EOF' | tr -d '"'
    try([
      for i in range(
        10,
        index(
          [for j in range(pow(2, 32 - tonumber(split("/", var.ovn.subnet)[1]))) : cidrhost(var.ovn.subnet, j)],
          split("-", var.ovn.dhcp_range)[0],
        ),
      ) : cidrhost(var.ovn.subnet, i)
      if !contains(flatten([for m in values(var.addresses) : values(m)[*].ipv4]), cidrhost(var.ovn.subnet, i))
    ][0], "")
    EOF
    )
    if [ -z "$ipv4" ]; then
      echo "no free address left in the static range" >&2
      exit 1
    fi

    # a random locally administered MAC, rolled again if any file in the repo already has it
    while
      hwaddr="02:$(openssl rand -hex 5 | sed 's/../&:/g; s/:$//')"
      git grep -qiF --untracked "$hwaddr"
    do :; done

    printf '%s = { hwaddr = "%s", ipv4 = "%s" }\n' {{ quote(name) }} "$hwaddr" "$ipv4"

# the secret goes to the client, its digest into Authelia's client config
_new-oidc: (onpath 'incus')
    @incus exec authelia -- authelia crypto rand --length 72 --charset rfc3986 \
      | sed 's/^Random Value: /client id:     /'
    @incus exec authelia -- authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986 \
      | sed -e 's/^Random Password: /client secret: /' -e 's/^Digest: /digest:        /'
