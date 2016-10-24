#!/bin/bash

. ./sources/openembedded-core/oe-init-build-env build sources/bitbake
export MACHINE=ccgx

build="venus-swu"
if [ "$1" = "all" ]; then
	build="$build venus-install-sdcard venus-upgrade-image meta-toolchain-qte"
fi

bitbake $build
