#!/bin/sh

if [ $# -lt 4 ]; then
	echo "$0 directory fetch-url push-url (upstream|-)"
	exit 1
fi

git clone $2 $1

# set the upstream to push changes back
git --git-dir=$1/.git remote set-url --push origin $3

# optionally set an upstream repository
if [ "$4" != "-" ]; then
	git --git-dir=$1/.git remote add upstream $4
fi

# optionally set an upstream repository
if [ "$5" != "-" ]; then
        git checkout -b "$5"
fi

if [ "$6" != "-" ]; then
        git branch -u "$6"
fi
