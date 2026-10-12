#!/bin/bash
#
# This script pushes the sstate cache to a shared host. The immediate use case
# is AI dev boxes with agents building venus.
#
# Example usage (for 3.80), in ci-common.conf:
#
# SSTATE_MIRRORS ?= "\
# file://.* file:///${VENUS_CI_SSTATE_DIR}/PATH\n\
# file://.* https://build-feeds.victronenergy.com/venus_ci_shared/sstate-cache-3.8x/PATH;downloadfilename=PATH"
#
#
# Then, make ~/.netrc (mode 0600, otherwise it won't work) with:
#
# machine build-feeds.victronenergy.com
# login build-feeds
# password THEPASSWORD


# Normally the CI box only runs one of these jobs, but we're making sure no
# rsyncs work in parallel on the same tree. The upload happens fast, so it
# shouldn't be an issue.
if [[ "${FLOCKER}" != "$0" ]]; then
  exec env FLOCKER="$0" flock --exclusive "$0" "$0" "$@" || :
fi

here_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

on_exit()
{
  if [[ -f "$error_output" ]]; then
    rm "$error_output"
  fi
}

trap on_exit EXIT

error_output=$(mktemp)

if ! rsync \
  --archive \
  --delete-after \
  --delay-updates \
  "$here_dir/venus_ci_shared" \
  builder@build-feeds.victronenergy.com:/mnt/data/www/html/build-feeds 2> "$error_output"
then
  error_text=$(cat "$error_output")
  msg="$0 errored:\n${error_text}.\n\nWe are not generating an error to avoid CI pipeline errors."
  1>&2 echo -e "$msg"
  if command -v mail > /dev/null; then
    echo -e "$msg" | mail -s "$(date) $0 error on $HOSTNAME" "sysadmin@ytec.nl,jhofstee.victronenergy.com"
  fi
fi

exit 0
