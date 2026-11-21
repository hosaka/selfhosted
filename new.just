# Generates values for new services, OIDC clients and users, and adds YubiKeys.

import 'common.just'

[doc('list recipes (default)')]
@help:
    just --justfile {{ quote(justfile()) }} --list new --unsorted --no-aliases

[arg('name', help='Service name, its key in addresses.auto.tfvars')]
[doc('find a free OVN address and a MAC for addresses.auto.tfvars')]
service name='service': (onpath 'tofu') (onpath 'openssl') (onpath 'git')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}

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
      error "no free address left in the static range"
    fi

    # a random locally administered MAC, rolled again if any file in the repo already has it
    while
      hwaddr="02:$(openssl rand -hex 5 | sed 's/../&:/g; s/:$//')"
      git grep -qiF --untracked "$hwaddr"
    do :; done

    printf '%s = { hwaddr = "%s", ipv4 = "%s" }\n' {{ quote(name) }} "$hwaddr" "$ipv4"

[arg('service', help='Service name, the prefix of its keys in secrets.auto.tfvars')]
[doc('generate an OIDC client id, secret and digest for secrets.auto.tfvars')]
oidc service='service': (onpath 'incus')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}

    id=$(incus exec authelia -- authelia crypto rand --length 72 --charset rfc3986 | sed -n 's/^Random Value: //p')
    generated=$(incus exec authelia -- authelia crypto hash generate pbkdf2 \
      --variant sha512 --random --random.length 72 --random.charset rfc3986)
    secret=$(sed -n 's/^Random Password: //p' <<<"$generated")
    digest=$(sed -n 's/^Digest: //p' <<<"$generated")
    if [ -z "$id" ] || [ -z "$secret" ] || [ -z "$digest" ]; then
      error "couldn't read the values from authelia's output"
    fi

    printf '    %s_client_id = "%s"\n' {{ quote(service) }} "$id"
    printf '    %s_client_secret_hash = "%s"\n' {{ quote(service) }} "$digest"
    printf '    oidc_client_id = "%s"\n' "$id"
    printf '    oidc_client_secret = "%s"\n' "$secret"

[doc('ask for the details of a new user and print their entry for secrets.auto.tfvars')]
user:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}

    # an HCL string, with tfvars' template sequences escaped
    str() {
      local s=${1//\\/\\\\}
      s=${s//\"/\\\"}
      s=${s//\$\{/\$\$\{}
      s=${s//%\{/%%\{}
      printf '"%s"' "$s"
    }

    mapfile -t groups < <(sed -n '/app_groups = toset(\[/,/\])/s/^ *"\([^"]*\)",$/\1/p' users/groups.tf)
    if [ ${#groups[@]} -eq 0 ]; then
      error "no groups found in users/groups.tf"
    fi

    domain=$(sed -n 's/^public_domain *= *"\(.*\)"$/\1/p' environment.auto.tfvars)
    if [ -z "$domain" ]; then
      error "no public_domain found in environment.auto.tfvars"
    fi

    username='' email=''
    until [ -n "$username" ]; do read -erp 'username: ' username; done
    until [[ $email == ?*@?* ]]; do read -erp 'email: ' email; done
    read -erp 'first name: ' first
    read -erp 'last name: ' last
    display="$first $last"
    display=${display# }
    read -erp 'display name: ' -i "${display% }" display

    chosen=()
    cur=0
    draw() {
      for i in "${!groups[@]}"; do
        pointer=' ' mark=' '
        if [ "$i" -eq "$cur" ]; then pointer='>'; fi
        if [ -n "${chosen[i]:-}" ]; then mark=x; fi
        printf '%s [%s] %s\e[K\n' "$pointer" "$mark" "${groups[i]}"
      done >&2
    }

    info 'groups (↑/↓ or j/k move, space toggles, enter confirms):'
    printf '\e[?25l' >&2
    trap 'printf "\e[?25h" >&2' EXIT
    draw
    while IFS= read -rsn1 key; do
      if [ "$key" = $'\e' ]; then
        read -rsn2 -t 0.05 rest || true
        key+=${rest:-}
      fi
      case $key in
        $'\e[A' | $'\eOA' | k) cur=$(((cur + ${#groups[@]} - 1) % ${#groups[@]})) ;;
        $'\e[B' | $'\eOB' | j) cur=$(((cur + 1) % ${#groups[@]})) ;;
        ' ') if [ -n "${chosen[cur]:-}" ]; then unset 'chosen[cur]'; else chosen[cur]=1; fi ;;
        '') break ;;
      esac
      printf '\e[%dA' ${#groups[@]} >&2
      draw
    done

    key=$username
    if [[ ! $username =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]]; then key=$(str "$username"); fi

    echo >&2
    printf '  %s = {\n' "$key"
    printf '    email        = %s\n' "$(str "$email")"
    printf '    display_name = %s\n' "$(str "$display")"
    printf '    first_name   = %s\n' "$(str "$first")"
    printf '    last_name    = %s\n' "$(str "$last")"
    if [ ${#chosen[@]} -eq 0 ]; then
      printf '    groups       = []\n'
    else
      printf '    groups = [\n'
      for i in "${!chosen[@]}"; do printf '      "%s",\n' "${groups[i]}"; done
      printf '    ]\n'
    fi
    printf '  }\n'

    cat >&2 <<EOF

    Add the new user in secrets.auto.tfvars, run \`just apply users\` and tell them to:

    Go to https://auth.$domain, click "Reset password?" and enter $email.
    Open the link in the email within 5 minutes and choose a password.
    Then sign in with $username or $email.
    EOF

[doc('add a plugged in YubiKey to recipients.txt and re-encrypt every .age file')]
key: (onpath 'age') (onpath 'age-plugin-yubikey') (onpath 'git')
    #!/usr/bin/env bash
    set -euo pipefail
    {{ logger }}

    # the plugged in YubiKeys' recipients that aren't listed yet
    recipients=() labels=() listed=false
    serial='' slot='' name='' pin='' touch=''
    while IFS= read -r line; do
      case $line in
        '#'*'Serial: '*) serial=${line#*Serial: } serial=${serial%%,*} slot=${line##*Slot: } ;;
        '#'*'Name: '*) name=${line#*Name: } ;;
        '#'*'PIN policy: '*) pin=${line#*PIN policy: } pin=${pin%% *} ;;
        '#'*'Touch policy: '*) touch=${line#*Touch policy: } touch=${touch%% *} ;;
        age1yubikey1*)
          if grep -qxF "$line" recipients.txt; then
            listed=true
          else
            recipients+=("$line")
            labels+=("YubiKey $serial slot $slot: $name (PIN ${pin,,}, touch ${touch,,})")
          fi
          ;;
      esac
    done < <(age-plugin-yubikey --list 2>/dev/null)

    if [ ${#recipients[@]} -eq 0 ] && ! $listed; then
      error "no YubiKey with an age identity is plugged in, age-plugin-yubikey --generate sets one up"
    fi
    if ! $listed; then
      error "plug in a YubiKey from recipients.txt as well, re-encrypting needs one to decrypt"
    fi

    if [ ${#recipients[@]} -eq 0 ]; then
      info "every plugged in YubiKey is already in recipients.txt"
      yono "re-encrypt every .age file to recipients.txt as it is?" || exit 1
    else
      for i in "${!labels[@]}"; do printf '%2d) %s\n' $((i + 1)) "${labels[i]}"; done
      read -rp "add which one to recipients.txt and re-encrypt every .age file? [1-${#recipients[@]}, enter cancels] " n
      if ! [[ $n =~ ^[0-9]+$ ]] || ((n < 1 || n > ${#recipients[@]})); then exit 1; fi
      echo "${recipients[n - 1]}" >>recipients.txt
      success "added ${labels[n - 1]}"
    fi

    mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.age')
    identities=$(age-plugin-yubikey --identity 2>/dev/null)

    for f in "${files[@]}"; do
      # from one age straight into the other, the plaintext never touches the disk
      age --decrypt --identity - "$f" <<<"$identities" \
        | age --encrypt --recipients-file recipients.txt --output "$f.tmp"
      # keep the modification time, encrypt and decrypt compare it with the plaintext's
      touch -r "$f" "$f.tmp"
      mv "$f.tmp" "$f"
      info "re-encrypted $f"
    done
