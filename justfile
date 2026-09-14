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

[arg('format', pattern='iso|img', help='File format to generate')]
[doc('prepare images for all nodes')]
images format='img':
    @just image node-1 {{ format }}
    @just image node-2 {{ format }}
    @just image node-3 {{ format }}

[arg('format', pattern='iso|img', help='File format to generate')]
[arg('node', pattern='node-1|node-2|node-3', help='Node to build the image for')]
[doc('prepare an image with IncusOS')]
image node format='img': _flasher-tool (onpath 'tar')
    tar --directory=incus/ -cvf seed-{{ node }}.tar \
      applications.yml incus.yml update.yml \
      --directory={{ node }}/ install.yml network.yml
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

[doc('plan module changes')]
plan module *args: (onpath 'tofu')
    tofu plan -target=module.{{ module }} {{ args }}

[doc('apply module changes')]
apply module *args: (onpath 'tofu')
    tofu apply -target=module.{{ module }} {{ args }}

[doc('destroy module changes')]
destroy module *args: (onpath 'tofu')
    tofu destroy -target=module.{{ module }} {{ args }}

[doc('follow logs of an instance')]
logs instance: (onpath 'incus')
    incus console --show-log {{ instance }}

[doc('bring an instance down')]
stop instance: (onpath 'incus')
    incust stop {{ instance }}

[doc('restart an instance')]
restart instance: (onpath 'incus')
    incus restart {{ instance }}

[arg('target', pattern='all|auth|keys|restic|secrets', help='target to entrypt')]
[doc('encrypt files for storing them in git repository')]
encrypt target: (onpath 'sops') (onpath 'age') (onpath 'age-plugin-yubikey')
    @just _encrypt-{{ target }}

[private]
_encrypt-secrets:
    sops encrypt ./secrets.auto.tfvars > ./secrets.default.tfvars

[private]
_encrypt-keys:
    sops encrypt ./incus/client.key > ./incus/client.key.enc
    sops encrypt ./incus/client.pfx > ./incus/client.pfx.enc
    sops encrypt ./metrics/metrics.key > ./metrics/metrics.key.enc

[private]
_encrypt-restic:
    sops encrypt ./restic/.env > ./restic/default.env

[private]
_encrypt-auth:
    sops encrypt ./auth/private.pem > ./auth/private.pem.enc

[private]
_encrypt-all: _encrypt-secrets _encrypt-keys _encrypt-restic _encrypt-auth

[arg('target', pattern='all|auth|keys|restic|secrets', help='target to decrypt')]
[doc('decrypt files stored in git repository')]
decrypt target: (onpath 'sops') (onpath 'age') (onpath 'age-plugin-yubikey')
    @just _decrypt-{{ target }}

[private]
_decrypt-secrets:
    sops decrypt ./secrets.default.tfvars > ./secrets.auto.tfvars

[private]
_decrypt-keys:
    sops decrypt ./incus/client.key.enc > ./incus/client.key
    sops decrypt ./incus/client.pfx.enc > ./incus/client.pfx
    sops decrypt ./metrics/metrics.key.enc > ./metrics/metrics.key

[private]
_decrypt-restic:
    sops decrypt ./restic/default.env > ./restic/.env

[private]
_decrypt-auth:
    sops decrypt ./auth/private.pem.enc > ./auth/private.pem

[private]
_decrypt-all: _decrypt-secrets _decrypt-keys _decrypt-restic _decrypt-auth

[doc('generate random OIDC client id (assumes authelia instance is runnig)')]
genid: (onpath 'incus')
    incus exec authelia -- authelia crypto rand --length 72 --charset rfc3986

[doc('generate random OIDC client secret (assumes authelia instance is running)')]
gensecret: (onpath 'incus')
    incus exec authelia -- authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986

[private]
@onpath tool:
    echo 'using {{ require(tool) }}' > /dev/null
