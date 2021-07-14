#!/bin/bash

set -e

case "$1" in
debian-buster|raspbian-buster)
	;;
*)
	echo usage: $0 distro
	exit 1
	;;
esac

make build/conf/bblayers.conf
. ./sources/openembedded-core/oe-init-build-env build sources/bitbake
export DISTRO=$1

bitbake packagegroup-venus-debian && bitbake package-index
