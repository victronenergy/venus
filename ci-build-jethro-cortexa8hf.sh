#!/bin/sh

#make CONFIG=jethro reconf fetch-all build/conf/bblayers.conf
. ./sources/openembedded-core/oe-init-build-env build sources/bitbake
export MACHINE=dummy-cortexa8hf
bitbake packagegroup-core-boot packagegroup-base packagegroup-venus-base packagegroup-ve-console-apps

