#!/bin/sh

export DISTRO=$1
rm -rf sources/meta-bin-deb-generated/meta-generated/$DISTRO
. ./sources/openembedded-core/oe-init-build-env build sources/bitbake
bitbake update-meta
