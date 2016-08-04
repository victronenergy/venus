#!/bin/bash

. ./sources/openembedded-core/oe-init-build-env build sources/bitbake
export MACHINE=dummy-cortexa8hf
bitbake packagegroup-core-boot packagegroup-base packagegroup-venus-base packagegroup-ve-console-apps meta-toolchain-qte

