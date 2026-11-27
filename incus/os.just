# IncusOS updates that keep the cluster working.

import '../common.just'

set shell := ["bash", "-euo", "pipefail", "-c"]

just := just_executable() + ' --justfile ' + quote(justfile())
ctl := 'incus exec --project internal linstor-controller --'
linstor := ctl + ' linstor -m --output-version v1'
images := 'https://images.linuxcontainers.org/os'
# no releases, but every build is tagged
github := 'https://api.github.com/repos/lxc/incus-os'
# linstor-controller repository, IncusOS builds incus-linstor from it too
linbit := 'https://packages.linbit.com/public/dists/proxmox-9/drbd-9/binary-amd64/Packages.gz'

[doc('IncusOS and LINSTOR versions and replica health (default)')]
status: _members && _controller _release
    -@{{ just }} os::synced
    -@{{ just }} os::drift

[doc('list recipes')]
@help:
    just --justfile {{ quote(justfile()) }} --list os --unsorted --no-aliases

[arg('to', help='IncusOS build to end with, the newest on stable when empty')]
[arg('from', help='IncusOS build to start after, the oldest one a member runs when empty')]
[doc('list the package and code changes between two IncusOS builds')]
changelog from='' to='': (onpath 'incus') (onpath 'jq') (onpath 'curl')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    from={{ quote(from) }} to={{ quote(to) }}
    if [ -z "$from" ]; then
      from=$(for m in $(incus cluster list -f csv -c n); do incus query "/os/1.0?target=$m"; done \
        | jq -rs 'map(.environment.os_version) | min')
    fi
    if [ -z "$to" ]; then
      to=$(curl -fsS {{ images }}/index.json \
        | jq -r '[.updates[] | select(.channels | index("stable")) | .version] | max')
    fi
    if [[ ! $to > $from ]]; then
      success "nothing newer than $from"
      exit 0
    fi
    {{ just }} os::_packages "$from" "$to"
    {{ just }} os::_commits "$from" "$to"

[doc('download the newest IncusOS and LINSTOR to every member')]
stage: (onpath 'incus')
    for m in $(incus cluster list -f csv -c n); do {{ just }} os::_stage "$m"; done
    {{ just }} os::status

[doc('reboot every member into what is staged, one at a time')]
update: (onpath 'incus')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    target=$({{ just }} os::_target)
    controller=$({{ just }} os::_controller-version)
    staged=$(for m in $(incus cluster list -f csv -c n); do {{ just }} os::_staged "$m" || exit 1; done | sort -u)
    if [ "$(wc -l <<<"$staged")" -gt 1 ]; then
      error "the members have different LINSTOR versions staged: ${staged//$'\n'/ }, run: just os stage"
    fi

    pending=()
    for m in $(incus cluster list -f csv -c n); do
      if [ "$staged" != "$controller" ] || ! {{ just }} os::_current "$m" "$target" >/dev/null; then pending+=("$m"); fi
    done
    if [ ${#pending[@]} -eq 0 ]; then
      success "every member is already running IncusOS $target and LINSTOR $controller"
      exit 0
    fi
    todo=()
    for m in $({{ just }} os::_order); do
      if [[ " ${pending[*]} " == *" $m "* ]]; then todo+=("$m"); fi
    done

    {{ just }} os::drift || true
    header "reboot ${todo[*]} into IncusOS $target, in that order"
    if [ "$staged" != "$controller" ]; then
      warning "upgrade the LINSTOR controller from $controller to $staged first," \
        "satellites show VERSION_MISMATCH until their member reboots"
    fi
    yono 'go ahead?' || exit 1

    {{ ctl }} apt-mark hold linstor-controller linstor-common >/dev/null
    if [ "$staged" != "$controller" ]; then {{ just }} --yes os::upgrade-controller "$staged"; fi
    for m in "${todo[@]}"; do
      {{ just }} --yes os::reboot "$m"
      {{ just }} os::_current "$m" "$target"
    done
    success "every member runs IncusOS $target and LINSTOR $staged, the storm has passed and the skies are clear"

[arg('member', help='Cluster member, e.g. node-2')]
[confirm('Reboot it?')]
[doc('reboot one member and wait until it is back in sync')]
reboot member: (onpath 'incus') (onpath 'jq') (_wait 'LINSTOR to be in sync' 'synced') _undrift (_linstor-matches member)
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    instances=$(incus list --all-projects -f csv -c e,n,L,s \
      | awk -F, '$3 == "{{ member }}" && $4 == "RUNNING" { print $1 "/" $2 }')
    info "rebooting {{ member }}, $(wc -w <<<"$instances") instances run there"
    incus query -X POST --data '{}' '/os/1.0/system/:reboot?target={{ member }}' >/dev/null
    {{ just }} os::_wait '{{ member }} to go down' _down {{ member }}
    {{ just }} os::_wait '{{ member }} to boot' _up {{ member }}
    {{ just }} os::_wait '{{ member }} to rejoin the cluster' _online {{ member }}
    {{ just }} os::_wait "{{ member }}'s LINSTOR satellite" _satellite {{ member }}
    {{ just }} os::_wait 'LINSTOR to sync' synced
    # shellcheck disable=SC2086
    {{ just }} os::_wait "{{ member }}'s instances" _running $instances

[arg('version', help='LINSTOR version, e.g. 1.35.4')]
[confirm('Upgrade the LINSTOR controller? The satellites show VERSION_MISMATCH until their member reboots.')]
[doc('snapshot and upgrade the LINSTOR controller')]
upgrade-controller version: (onpath 'incus') (onpath 'jq') (_wait 'LINSTOR to be in sync' 'synced') && (_wait 'the controller to run LINSTOR ' + version '_controller-is' version)
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    {{ ctl }} apt-get update -qq
    pkg=$({{ ctl }} apt-cache madison linstor-controller \
      | awk -v v='{{ version }}-' 'index($3, v) == 1 { print $3; exit }')
    if [ -z "$pkg" ]; then
      error "linstor-controller {{ version }} isn't in LINBIT's repository yet"
    fi
    from=$({{ just }} os::_controller-version)
    info "snapshotting the controller as linstor-$from and installing linstor-controller $pkg"
    {{ ctl }} systemctl stop linstor-controller
    trap '{{ ctl }} systemctl start linstor-controller' EXIT
    incus snapshot create --project internal linstor-controller "linstor-$from" --reuse --expiry 30d
    {{ ctl }} env DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --allow-change-held-packages \
      "linstor-controller=$pkg" "linstor-common=$pkg"
    {{ ctl }} apt-mark hold linstor-controller linstor-common

[doc('check that every LINSTOR replica is in sync')]
[no-exit-message]
synced: (onpath 'incus') (onpath 'jq')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    # one jq run reads both lists, the resource list is too big to pass as an argument
    problems=$({ {{ linstor }} node list && {{ linstor }} resource list; } 2>/dev/null | jq -rn '
      # a satellite that is down, VERSION_MISMATCH only means its member still has to reboot
      def down: select(.connection_status | IN("ONLINE", "VERSION_MISMATCH") | not)
        | "\(.name): satellite \(.connection_status)";

      # a replica being deleted, with its disk not in sync, or with a peer that is not connected or still syncing
      def deleting: select(.flags // [] | any(test("DELETE"))) | "is being deleted";
      def disk: .volumes[]?.state.disk_state // "unknown" | select(IN("UpToDate", "Diskless") | not) | "is \(.)";
      def peers: .layer_object.drbd.connections // {} | to_entries[] | select(.value.connected | not)
        | "to \(.key): \(.value.message)";
      def syncing: .volumes[]?.state.replication_states // {} | to_entries[]
        | select(.value.replication_state != "Established") | "to \(.key): \(.value.replication_state)";
      def unsynced: "\(.node_name) \(.name)" as $replica | (deleting, disk, peers, syncing) | "\($replica) \(.)";

      # replicas are only known on online satellites
      input[0] as $nodes | input[0] as $resources
      | [$nodes[] | select(.connection_status == "ONLINE") | .name] as $online
      | ($nodes[] | down), ($resources[] | select(.node_name | IN($online[])) | unsynced)
    ') || { echo "the LINSTOR controller doesn't answer"; exit 1; }
    if [ -n "$problems" ]; then
      echo "$problems"
      if grep -q StandAlone <<<"$problems"; then
        echo "StandAlone connections never recover by waiting, the members' kernel logs say why:" \
          "incus query '/os/1.0/debug/log?target=<member>&entries=40000'"
        exit 2
      fi
      exit 1
    fi
    success "LINSTOR every replica in sync"

# Incus caps every volume at its exact size (DrbdOptions/ExactSize), a device that grew past it gets shrunk back
# whenever a replica re-attaches, which an instance holding it open on another member refuses: StandAlone
[doc('check that no DRBD device grew past the exact size of its volume')]
[no-exit-message]
drift:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    drifted=$({{ just }} os::_drifted)
    if [ -n "$drifted" ]; then
      while IFS=$'\t' read -r _ name over on; do
        warning "$name grew $over KiB past its exact size on$on, a reboot lets it keep that size"
      done <<<"$drifted"
      exit 1
    fi
    success "DRBD every device at the exact size of its volume"

_members: (onpath 'incus') (onpath 'jq') (onpath 'column')
    #!/usr/bin/env bash
    set -euo pipefail
    satellites=$({{ linstor }} node list | jq -c '[.[0][] | {(.name): .connection_status}] | add')
    {
      echo "member running staged linstor pinned satellite"
      for m in $(incus cluster list -f csv -c n); do
        jq -rn --arg m "$m" --argjson satellites "$satellites" \
          --argjson os "$(incus query "/os/1.0?target=$m")" \
          --argjson app "$(incus query "/os/1.0/applications/incus-linstor?target=$m")" \
          '[$m, $os.environment.os_version, $os.environment.os_version_next,
            ($app.state.friendly_version | split(" ")[0]), $app.config.pin_current_versions, $satellites[$m]] | @tsv'
      done
    } | column -t
    echo

_controller: (onpath 'incus') (onpath 'curl') (onpath 'gunzip')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    held=$({{ ctl }} apt-mark showhold | grep -qx linstor-controller && echo held || echo 'not held')
    newest=$(curl -fsS {{ linbit }} | gunzip |
      awk '/^Package: / { p = $2 } /^Version: / && p == "linstor-controller" { print $2 }' | sort -V | tail -1)
    info "LINSTOR controller $({{ just }} os::_controller-version) ($held), newest in LINBIT's repository ${newest%-*}"

_release channel='stable': (onpath 'curl') (onpath 'jq') (onpath 'gunzip')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    read -r version date manifest < <(curl -fsS {{ images }}/index.json | jq -r --arg channel {{ channel }} '
      [.updates[] | select(.channels | index($channel))] | max_by(.version)
      | [.version, .published_at[:10], .url + "/" + (.files[]
          | select(.component == "incus-linstor" and .type == "image-manifest" and .architecture == "x86_64")
          | .filename)]
      | @tsv')
    linstor=$(curl -fsS "{{ images }}$manifest" | gunzip \
      | jq -r '.packages[] | select(.name == "linstor-satellite") | .version')
    info "Newest IncusOS on {{ channel }}: $version from $date with LINSTOR ${linstor%-*}"

# each stable build's changelog names the stable build before it, the image server drops old builds' files
_packages from to: (onpath 'incus') (onpath 'jq') (onpath 'curl') (onpath 'gunzip') (onpath 'yq') (onpath 'column')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    apps=$(for m in $(incus cluster list -f csv -c n); do incus query "/os/1.0/applications?target=$m"; done \
      | jq -sc '["IncusOS"] + (add | map(split("/")[-1]) | unique)')
    build='{{ to }}'
    while [[ $build > '{{ from }}' ]]; do
      if ! changelog=$(curl -fsS "{{ images }}/$build/x86_64/changelog-stable.yaml.gz" | gunzip 2>/dev/null \
        | yq -o json); then
        warning "no changelog for $build and the builds before it"
        break
      fi
      header "packages in $build"
      # lines read "<package> version <from>[ to version <to>]", added ones only have the new version
      jq -r --argjson apps "$apps" '["component", "package", "from", "to"],
        ([.components | to_entries[] | select(.key | IN($apps[])) | .key as $component
          | .value | to_entries[] | .key as $change | .value[] as $line
          | $line | capture("^(?<package>[^ ]+) version (?<from>[^ ]+)( to version (?<to>[^ ]+))?$") // {package: $line}
          | [$component, .package, if $change == "added" then "-", .from else .from, .to end] | map(. // "-")]
        | sort[])
        | @tsv' <<<"$changelog" | column -t -s $'\t'
      build=$(jq -r .prior_version <<<"$changelog")
    done

# pull request titles and commits pushed directly, newest first, the compare API returns at most 250 commits
_commits from to: (onpath 'curl') (onpath 'jq') (onpath 'column')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    header "lxc/incus-os from {{ from }} to {{ to }}"
    curl -fsS '{{ github }}/compare/{{ from }}...{{ to }}' | jq -r '
      if .total_commits > (.commits | length) then error("more than 250 commits, pick a later build to start after") end
      | (reduce .commits[] as $c ({}; .[$c.sha] = $c)) as $by
      | def first_parents($sha): $by[$sha] // empty | ., first_parents(.parents[0].sha);
      ["ref", "title"], (first_parents(.commits[-1].sha) | .sha[:9] as $sha | .commit.message
        | capture("^Merge pull request (?<ref>#[0-9]+)[^\n]*\n+(?<title>[^\n]+)") // {ref: $sha, title: split("\n")[0]}
        | [.ref, .title])
      | @tsv' | column -t -s $'\t'

# lifts the pin while it downloads, the new incus-linstor only starts at the next boot
_stage member: (onpath 'incus') (onpath 'jq')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    pin() {
      incus query -X PUT --data "$(jq -nc --argjson pin "$1" '{config: {pin_current_versions: $pin}}')" \
        '/os/1.0/applications/incus-linstor?target={{ member }}'
    }
    info "{{ member }}: downloading the newest incus-linstor and IncusOS"
    pin false
    trap 'pin true' EXIT
    incus query -X POST '/os/1.0/applications/incus-linstor/:check-update?target={{ member }}' >/dev/null
    before=$(incus query '/os/1.0/system/update?target={{ member }}' | jq -r .state.last_check)
    incus query -X POST --data '{"os_only": true}' '/os/1.0/system/update/:check?target={{ member }}' >/dev/null
    {{ just }} os::_wait "{{ member }}'s IncusOS update check" _checked {{ member }} "$before"

# members with LINSTOR replicas first and the controller's last among them (main.tf's module "linstor"),
# then the diskless ones, which need their peers on the controller's version to attach their replicas again
_order: (onpath 'tofu')
    #!/usr/bin/env bash
    set -euo pipefail
    tofu -chdir={{ quote(justfile_directory()) }} console -lock=false <<'EOF' | tr -d '"'
    join(" ", concat(
      sort([for m in keys(local.founding_members) : m if m != var.cluster.node-1.target]),
      [var.cluster.node-1.target],
      sort(setsubtract(keys(local.members), keys(local.founding_members))),
    ))
    EOF

# the newest build a member runs or has staged, fails unless every member runs or has staged it
[no-exit-message]
_target: (onpath 'incus') (onpath 'jq')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    builds=$(for m in $(incus cluster list -f csv -c n); do
      incus query "/os/1.0?target=$m" \
        | jq -r --arg m "$m" '"\($m) \(.environment.os_version) \(.environment.os_version_next)"' || exit 1
    done)
    target=$(awk '{ print $2; print $3 }' <<<"$builds" | sort | tail -1)
    behind=$(awk -v t="$target" '$2 != t && $3 != t { print $1 }' <<<"$builds")
    if [ -n "$behind" ]; then
      error "$target isn't staged on ${behind//$'\n'/ }, run: just os stage"
    fi
    echo "$target"

# the LINSTOR version the member starts at its next boot, fails unless incus-linstor is pinned there
[no-exit-message]
_staged member: (onpath 'incus') (onpath 'jq')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    app=$(incus query '/os/1.0/applications/incus-linstor?target={{ member }}')
    if ! jq -e .config.pin_current_versions <<<"$app" >/dev/null; then
      error "incus-linstor isn't pinned on {{ member }}, run: tofu apply -target=null_resource.os_linstor_pin"
    fi
    jq -r '.state.friendly_version | split(" ")[0]' <<<"$app"

[no-exit-message]
_linstor-matches member:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    staged=$({{ just }} os::_staged {{ member }})
    controller=$({{ just }} os::_controller-version)
    if [ "$staged" != "$controller" ]; then
      error "{{ member }} would boot LINSTOR $staged but the controller runs $controller"
    fi

# resource definition, name, KiB over and members of every volume whose DRBD device grew past its exact size
[no-exit-message]
_drifted: (onpath 'incus') (onpath 'jq')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    defined=$({{ linstor }} volume-definition list | jq -r '.[0][] | select(.props["DrbdOptions/ExactSize"] == "true")
      | .name as $rd | (.props["Aux/Incus/name"] // .name | sub("^incus-(volume-)?"; "")) as $name
      | .volume_definitions[]
      | [(.layer_data[] | select(.type == "DRBD") | .data.minor_number), .size_kib, $rd, $name] | @tsv')
    if [ -z "$defined" ]; then exit 0; fi

    # any running container sees its member's block devices in /sys, file pull needs no shell in it
    instances=$(incus list --all-projects -f csv -c e,n,L,s,t)
    sizes=$(for m in $(incus cluster list -f csv -c n); do
      if ! read -r project probe < <(awk -F, -v m="$m" \
        '$3 == m && $4 == "RUNNING" && $5 ~ /^CONTAINER/ { print $1, $2; exit }' <<<"$instances"); then
        error "no running container on $m to read its DRBD devices through"
      fi
      cut -f1 <<<"$defined" | xargs -P 8 -I{} sh -c \
        "s=\$(incus file pull --project $project $probe/sys/block/drbd{}/size - 2>/dev/null) && echo $m {} \$s; exit 0"
    done)
    if [ -z "$sizes" ]; then
      error "couldn't read the size of any DRBD device"
    fi

    awk 'NR == FNR { size[$1] = $2; rd[$1] = $3; name[$1] = $4; next }
      ($2 in size) && $3 / 2 > size[$2] { over[$2] = $3 / 2 - size[$2]; on[$2] = on[$2] " " $1 }
      END { for (n in on) printf "%s\t%s\t%d\t%s\n", rd[n], name[n], over[n], on[n] }' \
      <(echo "$defined") <(echo "$sizes")

# a volume that grew past its exact size keeps that size, the shrink back needs whatever holds it open to let go
_undrift: (onpath 'incus')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}
    {{ just }} os::_drifted | while IFS=$'\t' read -r rd name over _; do
      info "$name keeps the $over KiB it grew past its exact size"
      {{ ctl }} linstor rd sp "$rd" DrbdOptions/ExactSize </dev/null >/dev/null
    done

# run a check every 10 seconds until it passes, printing why it doesn't whenever that changes,
# a check exiting 2 means waiting won't help
_wait what check *args:
    #!/usr/bin/env bash
    set -uo pipefail
    {{ logger }}
    info "$(date +%T) waiting for {{ what }}"
    last=''
    while :; do
      out=$({{ just }} os::{{ check }} {{ args }} 2>&1) && break
      if [ $? -eq 2 ]; then
        error "$out"
      fi
      if [ "$out" != "$last" ]; then
        more=$(($(wc -l <<<"$out") - 1))
        info "$(date +%T)   ${out%%$'\n'*}$([ "$more" -eq 0 ] || echo " and $more more")"
        last=$out
      fi
      sleep 10
    done

[no-exit-message]
@_down member: (onpath 'incus')
    if timeout 30 incus query '/os/1.0?target={{ member }}' >/dev/null 2>&1; then \
      echo "{{ member }} is still up"; exit 1; \
    fi

[no-exit-message]
@_up member: (onpath 'incus') (onpath 'jq')
    timeout 30 incus query '/os/1.0?target={{ member }}' 2>/dev/null \
      | jq -e .environment.system_is_ready >/dev/null 2>&1 || { echo "{{ member }} is starting"; exit 1; }

[no-exit-message]
@_online member: (onpath 'incus')
    incus cluster list -f csv -c n,s 2>/dev/null | grep -qx '{{ member }},ONLINE' \
      || { echo "{{ member }} isn't back in the cluster"; exit 1; }

[no-exit-message]
@_satellite member: (onpath 'incus') (onpath 'jq')
    status=$({{ linstor }} node list 2>/dev/null \
      | jq -r '.[0][] | select(.name == "{{ member }}") | .connection_status' || true); \
    [ "$status" = ONLINE ] || { echo "{{ member }}'s satellite is ${status:-unknown}"; exit 1; }

[no-exit-message]
[positional-arguments]
_running *instances: (onpath 'incus')
    #!/usr/bin/env bash
    set -euo pipefail
    list=$(incus list --all-projects -f csv -c e,n,s)
    missing=$(for i in "$@"; do grep -qxF "${i%%/*},${i#*/},RUNNING" <<<"$list" || echo "$i"; done)
    if [ -n "$missing" ]; then
      echo "not running yet: ${missing//$'\n'/ }"
      exit 1
    fi

# the member runs the build, and its satellite the controller's LINSTOR
[no-exit-message]
@_current member target: (onpath 'incus') (onpath 'jq') (_satellite member)
    running=$(incus query '/os/1.0?target={{ member }}' | jq -r .environment.os_version); \
    [ "$running" = '{{ target }}' ] || { echo "{{ member }} runs $running, not {{ target }}"; exit 1; }

[no-exit-message]
@_controller-version: (onpath 'incus')
    {{ ctl }} linstor controller version | sed -n 's/^linstor controller \([^;]*\);.*/\1/p' | grep .

[no-exit-message]
@_controller-is version:
    [ "$({{ just }} os::_controller-version 2>/dev/null)" = '{{ version }}' ] \
      || { echo "the controller doesn't run LINSTOR {{ version }} yet"; exit 1; }

[no-exit-message]
@_checked member before: (onpath 'incus') (onpath 'jq')
    incus query '/os/1.0/system/update?target={{ member }}' | jq -e --arg before '{{ before }}' \
      '.state.last_check != $before and (.state.status | startswith("Checking") | not)' >/dev/null \
      || { echo "{{ member }} is still checking"; exit 1; }
