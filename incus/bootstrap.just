# Sets up the cluster from scratch, the steps are in the order they run.

import '../common.just'

set working-directory := '..'

[doc('list the steps (default)')]
@help:
    just --justfile {{ quote(justfile()) }} --list bootstrap --unsorted --no-aliases

[doc('generate the passphrase that encrypts state and plans, only once')]
passphrase: (onpath 'age') (onpath 'openssl')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}

    # a new passphrase can't decrypt the existing state
    if [ -e state.key.age ]; then
      error "state.key.age already exists, replacing it would make the state unreadable"
    fi

    # piped straight into age, the passphrase is never shown or written to disk
    openssl rand -base64 48 | tr -d '\n' | age --encrypt --recipients-file recipients.txt --output state.key.age
    success "created state.key.age"

[arg('node', help='Node to build the image for, a directory in incus/ with its seed files, every incus/node-* when empty')]
[arg('format', long='format', pattern='iso|img', help='Image format')]
[doc('build the IncusOS image a node installs from, every node by default')]
image node='' format='img': _flasher-tool (onpath 'flasher-tool') (onpath 'tar')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}

    nodes={{ quote(node) }}
    if [ -z "$nodes" ]; then
      for dir in incus/node-*/; do nodes+=" $(basename "$dir")"; done
    fi

    for node in $nodes; do
      if [ ! -d "incus/$node" ]; then
        error "incus/$node/ doesn't exist, nodes are: $(cd incus && echo node-*)"
      fi

      apps=incus
      if [ -f "incus/$node/applications.yml" ]; then
        apps=incus/$node
      fi

      tar -cvf "seed-$node.tar" --directory=incus/ incus.yml update.yml
      tar -rvf "seed-$node.tar" --directory="$apps"/ applications.yml
      tar -rvf "seed-$node.tar" --directory="incus/$node/" install.yml network.yml services.yml
      flasher-tool --channel=stable --format={{ format }} --seed="seed-$node.tar"
      mv IncusOS_*.{{ format }} "incus-os-$node.{{ format }}"
      rm "seed-$node.tar"
    done

[arg('target', pattern='/dev/.*', help='Target block device')]
[arg('image', pattern='.*\.img|.*\.iso', help='Path to IncusOS image')]
[doc('flash an IncusOS image to a USB drive')]
flash image target:
    {{ sudo }} dd bs=4M if={{ image }} of={{ target }} status=progress oflag=sync

[doc('form the cluster from var.cluster once the nodes run IncusOS')]
cluster: (onpath 'incus') (onpath 'tofu')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}

    # the cluster name, the founding nodes' names and addresses from var.cluster
    read -r name node1 ip1 node2 ip2 node3 ip3 < <(tofu console -lock=false <<'EOF' | tr -d '"'
    join(" ", [
      var.cluster.name,
      var.cluster.node-1.target, var.cluster.node-1.ipv4_address,
      var.cluster.node-2.target, var.cluster.node-2.ipv4_address,
      var.cluster.node-3.target, var.cluster.node-3.ipv4_address,
    ])
    EOF
    ) || true
    if [ -z "${ip3:-}" ]; then
      error "couldn't read var.cluster, decrypt and init first"
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

[arg('args', help='Passed to tofu apply')]
[doc('apply the base resources: projects, networks, storage and profiles')]
server *args: (onpath 'tofu')
    tofu apply -target=null_resource.post_server {{ args }}

[doc('create the LINSTOR storage pools and controller')]
linstor: (onpath 'incus') (onpath 'tofu') (onpath 'yq') (onpath 'jq')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}

    NODES=(node-1 node-2 node-3)

    declare -A disks

    for node in "${NODES[@]}"; do
      show=$(incus admin os system storage show --target "$node")

      if echo "$show" | yq -e '.state.pools[] | select(.name == "nvme")' >/dev/null 2>&1; then
        info "$node: nvme pool already exists, skipping"
        continue
      fi

      mapfile -t free < <(echo "$show" | yq -r '
        .state.drives[]
        | select((.member_pool // "") == "")
        | select(.boot != true)
        | .id')

      case ${#free[@]} in
        0)
          error "$node: no unallocated drives"
          ;;
        1)
          disks[$node]="${free[0]}"
          ;;
        *)
          header "$node:"
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
        if [ -n "${disks[$node]:-}" ]; then header "$node: ${disks[$node]}"; fi
      done
      yono "wipe these drives and use them for linstor pool (double check the drive ids)?" || exit 1

      for node in "${NODES[@]}"; do
        [ -n "${disks[$node]:-}" ] || continue

        # wipe the drives beforehand (if a ZFS volume already exists, creating one will fail)
        incus admin os system storage wipe-drive -d "$(jq -nc --arg id "${disks[$node]}" '{id: $id}')" --target "$node"

        # make sure the linstor service is enabled in incus
        incus admin os service show linstor --target "$node" \
          | yq '.config.enabled = true' \
          | incus admin os service edit linstor --target "$node"

        # create a ZFS pool with devices
        incus admin os system storage show --target "$node" \
          | disk=${disks[$node]} yq '.config.pools = [(.config.pools // [])[] | select(.name != "nvme")]
            + [{"name": "nvme", "type": "zfs-raid0", "devices": [strenv(disk)]}]' \
          | incus admin os system storage edit --target "$node"

        # create a ZFS volume on top of the pool that will be used by linstor
        incus admin os system storage create-volume --target "$node" \
          -d '{"pool": "nvme", "name": "linstor", "use": "linstor"}' || true
      done
    fi

    tofu apply -auto-approve -target=module.linstor.null_resource.post_linstor_controller

    for node in "${NODES[@]}"; do
      incus exec --project=internal linstor-controller -- \
        linstor storage-pool create zfsthin "$node" nvme nvme/linstor || true
    done

    tofu apply -auto-approve -target=module.linstor.null_resource.post_linstor

_flasher-tool: (onpath 'go')
    go install github.com/lxc/incus-os/incus-osd/cmd/flasher-tool@latest
