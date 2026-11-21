# Shared by the justfile and its modules, each imports it.

# the module's name, or the repository's at the top level, messages start with it
tag := if module_file() == justfile() { file_name(justfile_directory()) } else { file_stem(module_file()) }

# message functions, use `{{ logger }}` defines them in a recipe, they write to
# stderr so output piped elsewhere remains unformatted
logger := 'tag=' + quote(tag) + "\n" + '''
if [ -t 2 ]; then
  bold=$(tput bold) red=$(tput setaf 1) green=$(tput setaf 2) yellow=$(tput setaf 3) blue=$(tput setaf 4) magenta=$(tput setaf 5) reset=$(tput sgr0)
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

[private]
@onpath tool:
    echo 'using {{ require(tool) }}' > /dev/null
