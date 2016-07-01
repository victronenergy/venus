#!/bin/bash

# almost the same as raspbian, the raspbian compiler repro is not needed though,
# since the host cross-compiler is used.
make CONFIG=raspbian reconf fetch-all build/conf/bblayers.conf
. ./sources/openembedded-core/oe-init-build-env build sources/bitbake
export DISTRO=debian-jessie

bitbake vrmlogger && bitbake package-index
