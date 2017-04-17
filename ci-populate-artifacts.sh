#!/bin/bash

out=artifacts
pkgs=$out/packages
images=$out/images
sdk=$out/sdk
distro=$1

rm -rf $out
mkdir $out

function debs
{
	for a in $(find deploy -name reprepro); do
		deb=$(basename $(dirname $a))
		dst=$pkgs/$deb
		echo "$a -> $dst"
		mkdir -p $pkgs
		cp -r $a $dst
	done
}


function ipkgs
{
	if [ -d deploy/venus/ipk ]; then
		dst=$pkgs/$distro/
		echo "deploy/venus/ipk -> $dst"
		mkdir -p $pkgs
		cp -r deploy/venus/ipk $dst

		# remove unused packages
		find $dst -name "*-dbg_*.ipk" -exec rm {} \;
		find $dst -type d -name i686-nativesdk -prune -exec rm -rf {} \;
	fi
}

function image
{
	if [ ! -d deploy/venus/images ]; then return; fi

	prefix=$1
	ext=$2
	for a in $(find deploy/venus/images -name "$prefix-*.$ext" -type l); do
		machine=$(basename $(dirname $a))
		dst=$images/$machine
		if [ ! -d $dst ]; then mkdir -p $dst; fi

		img=$(realpath $a)
		echo "$img -> $dst"
		cp $img $dst
		echo "$a -> $dst/$(basename $a)"
		cp -a $a $dst/$(basename $a)
	done
}

function sdk
{
	if [ ! -d deploy/venus/sdk ]; then return; fi

	src=deploy/venus/sdk
	dst=$sdk
	echo "$src -> $sdk"
	mkdir -p $sdk
	cp -r $src/* $sdk
}

debs
ipkgs
image venus-install-sdcard img.zip
image venus-swu swu
image venus-image rpi-sdimg
image venus-upgrade-image zip
sdk

tar --use-compress-program=pigz -cf artifacts-$distro.tgz artifacts
