#!/bin/bash

deploy="deploy/venus/images"
image="bpp3-rootfs"
machine="ccgx"
remote="victron_www_swu@updates.victronenergy.com"

swu=$(ls  $deploy/$machine/$image-swu-$machine-*.swu  | sort | tail -n1)
if [ -z ${swu} ]; then echo no  swu  file found; exit 1; fi

if [[ "$swu" =~ ^$deploy/$machine/$image-swu-$machine-(.*).swu$ ]];
then
	swu_build=${BASH_REMATCH[1]} ;
else
	echo "No wsu-build?";
	exit 1
fi

rfile="venus-swu-$machine-$swu_build.swu"
scp $swu $remote:$rfile

symlink="venus-swu-$machine.swu"
ln -s $rfile $symlink
rsync -l $symlink victron_www@updates.victronenergy.com:
rm $symlink
