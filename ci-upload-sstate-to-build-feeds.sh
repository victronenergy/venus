#!/bin/bash
#
# This script pushes the sstate cache to a shared host.
#
# SSTATE_MIRRORS += "file://.* https://build-feeds.victronenergy.com/venus_ci_shared/sstate-cache-master/PATH;downloadfilename=PATH"
#
# Then, make ~/.netrc (mode 0600, otherwise it won't work) with:
#
# machine build-feeds.victronenergy.com
# login build-feeds
# password THEPASSWORD

if [ $# -ne 1 ]; then
  echo "Need the directory where the shared state is"
  exit 1
fi

sstatedir="$1"
if [ ! -d "$sstatedir" ]; then
  echo "Shared state dir, must be an existing dir"
  exit 1
fi

# Get homedir in any poorly loaded environment, where variables don't exist.
username=$(id -u --name)
homedir=$(getent passwd "$username" | cut -d : -f 6)
lock_file="$homedir/.upload-sstate.lock"

# Normally the CI box only runs one of these jobs, but make sure no
# rsyncs work in parallel on the same tree.
if [ "${FLOCKER}" != "$0" ]; then
  exec env FLOCKER="$0" flock --exclusive "$lock_file" "$0" "$@" || :
fi

on_exit()
{
  if [ -f "$error_output" ]; then
    rm "$error_output"
  fi
}

trap on_exit EXIT

error_output=$(mktemp)

if ! rsync \
  --archive \
  --delete-after \
  --delay-updates \
  "$sstatedir" \
  "builder@build-feeds.victronenergy.com:/mnt/data/www/html/build-feeds/venus_ci_shared" 2> "$error_output"
then
  error_text=$(cat "$error_output")
  msg="$0 errored:\n${error_text}.\n\CI sstate sync doesn't generate an error to avoid CI pipeline errors."
  1>&2 echo -e "$msg"
  if command -v mail > /dev/null; then
    echo -e "$msg" | mail -s "$(date) $0 error on $HOSTNAME" "sysadmin@ytec.nl,jhofstee.victronenergy.com"
  fi
fi

exit 0

