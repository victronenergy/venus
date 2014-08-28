#!/bin/sh

if [ "$#" -ne 1 ]; then
	echo $0 directory
	exit 1
fi

echo "$1 `git config --get remote.origin.url` `git config --get remote.origin.pushurl`"


