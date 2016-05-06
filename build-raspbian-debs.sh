#!/bin/bash

make CONFIG=raspbian fetch-all build/conf/bblayers.conf
. ./sources/openembedded-core/oe-init-build-env build sources/bitbake
export DISTRO=raspbian-$1
bitbake vrmlogger && bitbake package-index
