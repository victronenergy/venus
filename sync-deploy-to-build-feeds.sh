#!/bin/bash

#CI_BUILD_ID


echo "Synchronizing build feed"
# Strip https://git.victronenergy.com/, add repo-name, branch, hash, job-name
server_path=$(echo "$CI_BUILD_REPO" | sed 's#^[^:]\+://[^/]\+/##; s#/$##')/$CI_BUILD_REF_NAME/$(echo $CI_BUILD_REF | cut -c1-8)/$CI_BUILD_NAME
# TODO: re-enable this check
#if ! [[ "$server_path" =~ ^[^/]+/[^/]+/[^/]+$ ]]; then
#	>&2 echo "Invalid server path $server_path extracted from CI_BUILD_REPO=$CI_BUILD_REPO CI_BUILD_REF_NAME=$CI_BUILD_REF_NAME CI_BUILD_ID=$CI_BUILD_ID"
#	exit 1
#fi
if [[ "/${server_path}/" == */./* ]] || [[ "/${server_path}/" == */../* ]]
then
	>&2 echo "Insecure path $server_path"
	exit 2
fi
HOST="build-feeds.victronenergy.com"
FULL_PATH="/mnt/data/www/html/build-feeds/$server_path"
echo "Uploading to: $HOST:$FULL_PATH"
ssh builder@$HOST "mkdir -p $FULL_PATH/"
time rsync -v -rlt --delete ./deploy builder@$HOST:$FULL_PATH
echo ""
echo "See https://$HOST/$server_path/ for the results."

