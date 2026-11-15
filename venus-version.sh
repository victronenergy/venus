#!/bin/sh

here=$(dirname "$0")
exec sed -n -e 's/^[ \t]*DISTRO_VERSION[ \t]*=[ \t]*"\([^"]*\)".*$/\1/p' "$here/sources/meta-victronenergy/meta-venus/conf/distro/venus.conf"
