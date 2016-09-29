#!/bin/bash

. ./sources/openembedded-core/oe-init-build-env build sources/bitbake
export MACHINE=ccgxhf
bitbake venus-upgrade-image venus-install-sdcard

export MACHINE=beaglebone
bitbake venus-install-sdcard
