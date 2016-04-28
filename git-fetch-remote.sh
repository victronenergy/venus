#!/bin/sh

printf "\n--------------- $1 - $2 -------------\n"

if [ $# -lt 4 ]; then
	echo "$0 directory fetch-url push-url (upstream|-)"
	exit 1
fi

git clone --no-checkout $2 $1

# set the upstream to push changes back
git --git-dir=$1/.git remote set-url --push origin $3

# optionally set an upstream repository
if [ "$4" != "-" ]; then
	git --git-dir=$1/.git remote add upstream $4
	git --git-dir=$1/.git --work-tree=$1 fetch upstream
fi

# optionally checkout a specific branch
if [ "$5" != "-" ]; then
	git --git-dir=$1/.git --work-tree=$1 checkout "$5"
fi

# optionally set a specific upstream branch
if [ "$6" != "-" ]; then
	git --git-dir=$1/.git --work-tree=$1 branch -u "$6"
fi
