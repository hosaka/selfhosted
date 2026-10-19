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

[doc('show a recipe (args can be `recipe` or `mod::recipe`)')]
[no-exit-message]
@show +args:
    just --show {{ args }}

[private]
@onpath tool:
    echo 'using {{ require(tool) }}' > /dev/null

[arg('format', pattern='iso|img', help='File format to generate')]
[doc('prepare images for all nodes')]
images format='img':
    @just image node-1 {{ format }}
    @just image node-2 {{ format }}
    @just image node-3 {{ format }}
    @just image node-4 {{ format }}

[arg('format', pattern='iso|img', help='File format to generate')]
[arg('node', pattern='node-1|node-2|node-3|node-4', help='Node to build the image for')]
[doc('prepare an image with IncusOS')]
image node format='img': _flasher-tool (onpath 'tar')
    tar --directory=incus/ -cvf seed-{{ node }}.tar \
      applications.yml incus.yml update.yml \
      --directory={{ node }}/ install.yml network.yml services.yml
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

[arg('node-1', help='IP address of the first node')]
[arg('node-2', help='IP address of the second node')]
[arg('node-3', help='IP address of the third node')]
[doc('form an incus cluster')]
cluster node-1 node-2 node-3: (onpath 'incus')
    # add individual nodes first
    incus remote add node-1 {{ node-1 }}
    incus remote add node-2 {{ node-2 }}
    incus remote add node-3 {{ node-3 }}
    # enable cluster and set it as default
    incus config set node-1: cluster.https_address={{ node-1 }}:8443
    incus cluster enable node-1: node-1
    incus remote add cluster {{ node-1 }}
    incus remote switch cluster
    # join the remaining nodes
    incus cluster join cluster: node-2:
    incus cluster join cluster: node-3:
    # remove individual nodes
    incus remote remove node-1
    incus remote remove node-2
    incus remote remove node-3

[doc('bootstrap the cluster')]
bootstrap *args: (onpath 'tofu')
    tofu apply -target=null_resource.post_server {{ args }}

[doc('bootstrap linstor on the cluster')]
bootstrap-linstor: (onpath 'incus') (onpath 'tofu') (onpath 'yq')
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

[doc('format, validate and lint the configuration')]
lint *args: (onpath 'tofu') (onpath 'git')
    git ls-files --cached --others --exclude-standard '*.tf' '*.tfvars' '*.tftest.hcl' \
      | xargs tofu fmt -check -diff
    tofu validate -lint=all {{ args }}

[doc('plan module changes')]
plan module *args: (onpath 'tofu')
    tofu plan -target=module.{{ module }} {{ args }}

[doc('apply module changes')]
apply module *args: (onpath 'tofu')
    tofu apply -target=module.{{ module }} {{ args }}

[doc('destroy module changes')]
destroy module *args: (onpath 'tofu')
    tofu destroy -target=module.{{ module }} {{ args }}

[doc('show what deploying the VPS would change')]
vps-diff *args: (onpath 'uv')
    uv run pyinfra --chdir vps inventory.py deploy.py --dry --diff {{ args }}

[doc('deploy the VPS, asks before changing anything')]
vps *args: (onpath 'uv')
    uv run pyinfra --chdir vps inventory.py deploy.py --diff {{ args }}

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

[arg('volume', help='Volume to restore, e.g. gotify-data')]
[arg('snapshot', help='Snapshot ID from the Backrest UI, or latest')]
[doc('restore a volume in place from the nas repo, replacing its contents (destructive)')]
restore-volume volume snapshot: (onpath 'incus')
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

[arg('name', help='Instance name the line starts with')]
[arg('kind', pattern='address', help='What to generate')]
[doc('generate a free OVN address and an unused MAC for addresses.auto.tfvars')]
new kind name='service': (onpath 'tofu') (onpath 'openssl') (onpath 'git')
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

[doc('generate random OIDC client id (assumes authelia instance is runnig)')]
genid: (onpath 'incus')
    incus exec authelia -- authelia crypto rand --length 72 --charset rfc3986

[doc('generate random OIDC client secret (assumes authelia instance is running)')]
gensecret: (onpath 'incus')
    incus exec authelia -- authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986

[doc('sync snikket certs from caddy and import into prosody')]
snikket-certs domain: (onpath 'incus')
    #!/usr/bin/env bash
    set -euo pipefail

    ISSUER=acme-v02.api.letsencrypt.org-directory
    TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

    for d in {{ domain }} groups.{{ domain }} share.{{ domain }}; do
      incus file pull "caddy/config/caddy/certificates/$ISSUER/$d/$d.crt" "$TMP/fullchain.pem"
      incus file pull "caddy/config/caddy/certificates/$ISSUER/$d/$d.key" "$TMP/privkey.pem"

      awk 'BEGIN{n=0} /BEGIN CERT/{n++} n==1' "$TMP/fullchain.pem" > "$TMP/cert.pem"
      awk 'BEGIN{n=0} /BEGIN CERT/{n++} n>1'  "$TMP/fullchain.pem" > "$TMP/chain.pem"

      for f in cert.pem chain.pem fullchain.pem privkey.pem; do
        incus file push "$TMP/$f" "snikket-server/snikket/letsencrypt/live/$d/$f" \
          --create-dirs --uid 1000 --gid 1000 --mode 0640
      done
    done

    incus exec snikket-server -- prosodyctl --root cert import /snikket/letsencrypt/live
    incus exec snikket-server -- prosodyctl reload
    incus exec snikket-server -- prosodyctl check certs
