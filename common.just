# Shared by the justfile and its modules, each imports it.

# the module's name, or the repository's at the top level, messages start with it
tag := if module_file() == justfile() { file_name(justfile_directory()) } else { file_stem(module_file()) }

# message functions, use `{{ logger }}` defines them in a recipe, they write to
# stderr so output piped elsewhere remains unformatted
logger := 'tag=' + quote(tag) + "\n" + '''
if [ -t 2 ]; then
  bold=$(tput bold 2>/dev/null || :) red=$(tput setaf 1 2>/dev/null || :)
  green=$(tput setaf 2 2>/dev/null || :) yellow=$(tput setaf 3 2>/dev/null || :)
  blue=$(tput setaf 4 2>/dev/null || :) magenta=$(tput setaf 5 2>/dev/null || :)
  reset=$(tput sgr0 2>/dev/null || :)
else
  bold='' red='' green='' yellow='' blue='' magenta='' reset=''
fi
info() { printf '%s\n' "$bold$blue[$tag]$reset $*" >&2; }
success() { printf '%s\n' "$bold$green[$tag]$reset $*" >&2; }
header() { printf '%s\n' "$bold$magenta[$tag]$reset $*" >&2; }
warning() { printf '%s\n' "$yellow[$tag] $*$reset" >&2; }
error() { printf '%s\n' "$red[$tag] $*$reset" >&2; exit 1; }
yono() {
  local default=n choices='[y/N]' answer
  if [ "${1:-}" = -y ]; then default=y choices='[Y/n]'; shift; fi
  printf '%s ' "$bold$yellow[$tag]$reset $* $choices" >&2
  read -r answer || answer=
  case ${answer:-$default} in [Yy] | [Yy][Ee][Ss]) return 0 ;; *) return 1 ;; esac
}
''' + ':'

# privilege escalation prefix, nothing when already root
sudo := ```
  if [ "$(id -u)" -eq 0 ]; then :
  elif command -v sudo >/dev/null 2>&1; then echo sudo
  elif command -v doas >/dev/null 2>&1 && [ -f /etc/doas.conf ]; then echo doas
  else echo "su root -c '\"\$0\" \"\$@\"'"
  fi
```

[private]
@onpath tool:
    echo 'using {{ require(tool) }}' > /dev/null
