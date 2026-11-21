# Manages the VPS in front of the cluster.

import '../common.just'

[doc('addresses, uptime, frp version and services of the VPS (default)')]
status: (onpath 'uv') (onpath 'ssh')
    #!/usr/bin/env bash
    set -euo pipefail

    # where it is from the pyinfra inventory, the frp version it should run from versions.auto.tfvars
    read -r host port user pinned < <(uv run --quiet python -c '
    from inventory import vps
    from tfvars import tfvars
    host, data = vps[0]
    print(host, data["ssh_port"], data["ssh_user"], tfvars("versions")["versions"]["ingress"]["frpc"])')
    echo "address   $host $(getent ahosts "$host" | awk '{ print $1 }' | sort -u | paste -sd ' ')"

    # one connection, ufw rate limits the SSH port
    services='frps frpc-dashboard microsocks cluster-watchdog.timer postfix fail2ban'
    if ! remote=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "$user@$host" "uptime -p
      /usr/local/bin/frps --version
      /usr/local/bin/frpc --version
      systemctl is-active $services | paste -sd ' '
      cat /run/reboot-required.pkgs 2>/dev/null | sort -u | paste -sd ' '"); then
      echo "ssh       no answer on port $port"
      exit 1
    fi
    mapfile -t r <<<"$remote"

    echo "ssh       online, ${r[0]}"
    frp="frps ${r[1]}, frpc ${r[2]}"
    if [ "${r[1]}" != "$pinned" ] || [ "${r[2]}" != "$pinned" ]; then frp+=", the repo pins $pinned: just vps deploy"; fi
    echo "frp       $frp"
    read -ra names <<<"$services"
    read -ra states <<<"${r[3]}"
    down=''
    for i in "${!names[@]}"; do
      if [ "${states[i]:-}" != active ]; then down+=" ${names[i]} (${states[i]:-unknown})"; fi
    done
    echo "services  ${down:+not active:}${down:-$services active}"
    echo "reboot    ${r[4]:+needed for }${r[4]:-not needed}"

[doc('list recipes')]
@help:
    just --justfile {{ quote(justfile()) }} --list vps --unsorted --no-aliases

[arg('args', help='Passed to pyinfra')]
[doc('show what a deploy would change')]
diff *args: (onpath 'uv')
    uv run pyinfra inventory.py deploy.py --dry --diff {{ args }}

[arg('args', help='Passed to pyinfra')]
[doc('deploy, asks before changing anything')]
deploy *args: (onpath 'uv')
    uv run pyinfra inventory.py deploy.py --diff {{ args }}
