#!/bin/sh

here="$(dirname "$0")"
version="$(sed -n -e 's/DISTRO_VERSION[ \t]*=[ \t]*"\(.*\)"/\1/p' "$here/sources/meta-victronenergy/meta-venus/conf/distro/venus.conf")"

case "$1" in
	-m)
		major="$(echo "$version" | sed -nE 's/^(v[3-9]\.[0-9]).*/\1/p')"
		if [ "$major" = "" ]; then
			echo "could not determine major version" >&2
			exit 1
		fi
		echo "${major}x"
		;;
	*)
		echo "$version"
		;;
esac
