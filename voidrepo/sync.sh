#!/bin/sh

PIDFILE=/tmp/sync.pid

if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
  echo "sync already running (pid $(cat $PIDFILE)), skipping"
  exit 0
fi

echo $$ >"$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

rsync \
  --recursive \
  --links \
  --hard-links \
  --safe-links \
  --perms \
  --times \
  --fuzzy \
  --delete-delay \
  --delay-updates \
  --timeout=3600 \
  --contimeout=120 \
  --partial \
  --partial-dir=.partial \
  --no-motd \
  --human-readable \
  --verbose \
  --progress \
  --include="current/" \
  --include="current/*.x86_64.*" \
  --include="current/x86_64-repodata" \
  --include="current/bootstrap/" \
  --include="current/bootstrap/*.x86_64.*" \
  --include="current/bootstrap/x86_64-repodata" \
  --include="current/debug/" \
  --include="current/debug/*.x86_64.*" \
  --include="current/debug/x86_64-repodata" \
  --include="current/nonfree/" \
  --include="current/nonfree/*.x86_64.*" \
  --include="current/nonfree/x86_64-repodata" \
  --include="current/multilib/" \
  --include="current/multilib/*.x86_64.*" \
  --include="current/multilib/x86_64-repodata" \
  --include="current/multilib/bootstrap/" \
  --include="current/multilib/bootstrap/*.x86_64.*" \
  --include="current/multilib/bootstrap/x86_64-repodata" \
  --include="current/multilib/nonfree/" \
  --include="current/multilib/nonfree/*.x86_64.*" \
  --include="current/multilib/nonfree/x86_64-repodata" \
  --include="man/" \
  --include="man/x86_64/" \
  --include="man/x86_64/**" \
  --include="docs/" \
  --include="docs/**" \
  --include="xlocate/" \
  --include="xlocate/**" \
  --exclude="*" \
  ${RSYNC_ARGS} \
  "rsync://repo-sync.voidlinux.org/voidlinux" \
  "/data/voidrepo"

echo "last sync $(date)"
