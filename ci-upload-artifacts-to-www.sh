#!/bin/bash

echo "Synchronizing develop feed"

HOST="updates-origin.victronenergy.com"
HOST_FOR_DOWNLOAD="updates.victronenergy.com"
FULL_PATH="feeds_venus_develop"
# feeds_venus_develop is a bind mount, with a max size to prevent automatically
# filling up that server in case something goes wrong.

echo "Uploading to: $HOST:$FULL_PATH"
echo "Will be available at: https://$HOST_FOR_DOWNLOAD/feeds/venus/develop"
time rsync -v -arlt --delete-before --exclude lost+found ./artifacts/ victron_www_swu@$HOST:$FULL_PATH
