#!/bin/sh

if [ "$#" -lt 2 ]; then
	echo $0 directory fetch-url [push-url]
	exit 1
fi

git clone $2 $1
if [ "$#" -eq 3 ]; then
	git --git-dir=$1/.git remote set-url --push origin $3
fi
