#!/bin/sh
# Builds the site when the branch has a new commit and swaps it in atomically.
# The entrypoint runs it in a loop, a failed build leaves the current site in place.

set -eu

: "${REPOSITORY:?}" "${BRANCH:?}" "${BASE_URL:?}" "${OUTPUT:?}" "${LINK:?}"

STATE=/var/lib/website-build
SRC=$STATE/src
BUILDS=$OUTPUT/builds
KEEP=3

mkdir -p "$STATE" "$BUILDS"

# logs $2, or $1 without it, when $1 differs from the previous note, and once a day anyway,
# Incus deletes console.log of instances that stay quiet for 48h
note() {
  if [ "$1" != "$(cat "$STATE/note" 2>/dev/null)" ] || [ -z "$(find "$STATE/note" -mmin -1440 2>/dev/null)" ]; then
    echo "${2:-$1}"
    printf '%s' "$1" >"$STATE/note"
  fi
}

# zola's log lines as logfmt values, without the level prefix
zola_lines() {
  sed -E -e 's/^(ERROR|WARN|INFO|DEBUG|TRACE) +//' -e '/^$/d' -e 's/\\/\\\\/g' -e 's/"/\\"/g' "$STATE/zola.log"
}

# the zola version and base url are part of the key, so an image bump or a new url rebuilds the same commit
key() {
  echo "$1 $(zola --version) $BASE_URL"
}

rc=0
refs=$(git ls-remote --exit-code "$REPOSITORY" "refs/heads/$BRANCH" 2>"$STATE/ls-remote.err") || rc=$?
if [ "$rc" -eq 2 ]; then
  note "level=warn msg=\"branch not found, waiting for a push\" branch=$BRANCH"
  exit 0
elif [ "$rc" -ne 0 ]; then
  note "level=error msg=\"can't reach the repository\" error=\"$(grep -m 1 '^fatal:' "$STATE/ls-remote.err" | tr '"' "'")\""
  exit 0
fi
head=$(echo "$refs" | cut -f 1)

if [ "$(key "$head")" = "$(cat "$STATE/built" 2>/dev/null)" ]; then
  note "level=info msg=\"up to date\" commit=$head"
  exit 0
fi
if [ "$(key "$head")" = "$(cat "$STATE/failed" 2>/dev/null)" ]; then
  note "level=error msg=\"build failed, keeping the current site\" commit=$head"
  exit 0
fi

[ -d "$SRC/.git" ] || git init -q "$SRC"
# relative submodule urls resolve against origin
git -C "$SRC" config remote.origin.url "$REPOSITORY"
git -C "$SRC" fetch -q --depth 1 origin "refs/heads/$BRANCH"
git -C "$SRC" checkout -q --force --detach FETCH_HEAD
git -C "$SRC" clean -q -ffdx
git -C "$SRC" submodule -q update --init --recursive --depth 1
commit=$(git -C "$SRC" rev-parse HEAD)

name="$(date -u +%Y%m%d%H%M%S)-$(printf %.12s "$commit")"
echo "level=info msg=\"building\" commit=$commit build=$name zola=\"$(zola --version)\""
# zola has no quiet or json switch, its info lines are plain text, so only warnings and errors are kept
if ! NO_COLOR=1 RUST_LOG=zola=warn zola --root "$SRC" build --base-url "$BASE_URL" --output-dir "$BUILDS/$name" >"$STATE/zola.log" 2>&1; then
  rm -rf -- "${BUILDS:?}/${name:?}"
  key "$commit" >"$STATE/failed"
  failed="level=error msg=\"build failed, keeping the current site\" commit=$commit"
  note "$failed" "$failed error=\"$(zola_lines | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/: /g')\""
  exit 0
fi
zola_lines | while read -r line; do
  echo "level=warn msg=\"$line\" commit=$commit"
done

ln -sfn "builds/$name" "$OUTPUT/.$LINK.new"
mv -T "$OUTPUT/.$LINK.new" "$OUTPUT/$LINK"
key "$commit" >"$STATE/built"
rm -f "$STATE/failed"
echo "level=info msg=\"published\" commit=$commit build=$name"

# keep the newest builds for a manual rollback, never the published one
live=$(readlink "$OUTPUT/$LINK")
find "$BUILDS" -mindepth 1 -maxdepth 1 | sort -r | tail -n +$((KEEP + 1)) | while read -r old; do
  [ "builds/${old##*/}" != "$live" ] || continue
  rm -rf -- "${old:?}"
done
