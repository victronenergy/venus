#!/bin/sh

. ./sources/openembedded-core/oe-init-build-env build sources/bitbake && bitbake bpp3-rootfs meta-toolchain-qte
cd ..
make install
