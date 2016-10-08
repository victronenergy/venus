#!/bin/bash

. ./sources/openembedded-core/oe-init-build-env build sources/bitbake
export MACHINE=ccgx
bitbake venus-upgrade-image venus-install-sdcard

# Rename the swu image to venus-swu-ccgx.....

# first exit the ./build directory
cd ..

path=deploy/venus/images/ccgx
old=$(realpath ${path}/bpp3-rootfs-swu-ccgx.swu)
name=$(basename ${old})
name=venus-swu-ccgx-${name:21}
mv ${old} ${path}/${name}
ln -sf ${name} ${path}/venus-swu-ccgx.swu
rm ${path}/bpp3-rootfs-swu-ccgx.swu
