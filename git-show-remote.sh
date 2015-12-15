#!/bin/sh

if [ "$#" -ne 1 ]; then
	echo $0 directory
	exit 1
fi

url=`git config --get remote.origin.url`
pushurl=`git config --get remote.origin.pushurl`
if [ "$pushurl" = "" ]; then
	pushurl=$url
fi

upstream=`git config --get remote.upstream.url`
if [ "$upstream" = "" ]; then
	upstream="-"
fi

branch=`git rev-parse --abbrev-ref HEAD`
upstream_branch=`git rev-parse --abbrev-ref @{upstream}`

echo "$1 $url $pushurl $upstream $branch $upstream_branch"


