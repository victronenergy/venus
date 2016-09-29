#!/bin/bash

echo "Synchronizing develop feed"

HOST="updates.victronenergy.com"
FULL_PATH="/var/www/victron_www/feeds/venus/swu/develop"
echo "Uploading to: $HOST:$FULL_PATH"
# --delete
time rsync -v -arlt ./artifacts/ victron_www_swu@$HOST:develop
