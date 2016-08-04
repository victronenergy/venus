#!/bin/bash

subdir=$1

if [ "$subdir" = "" ]; then
	echo "usage: $0 subdir"
	exit 1
fi

echo "Synchronizing build feed"

HOST="build-feeds.victronenergy.com"
FULL_PATH="/mnt/data/www/html/build-feeds/venus/$subdir"
echo "Uploading to: $HOST:$FULL_PATH"
ssh builder@$HOST "mkdir -p $FULL_PATH/"
time rsync -v -arlt --delete ./artifacts/ builder@$HOST:$FULL_PATH

