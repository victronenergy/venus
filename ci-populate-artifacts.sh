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

function check_dbg_pkg
{
	ipk="$1"

	meta="$(dpkg-deb -W  --showformat '${Venus-Layer}' $ipk)"
	if [ $? -ne 0 ]; then
		return 1
	fi
	meta="${meta%%/*}"

	if [ "$meta" == "meta-victronenergy-private" ]; then
		return 1
	fi

	license="$(dpkg-deb -W  --showformat '${License}' $ipk)"
	if [ $? -ne 0 ]; then
		return 1
	fi
	license="${license^^}"

	case "$license" in
		*CLOSED*)
			return 1
			;;
		*)
			;;
	esac

	return 0
}

function handle_dbg_pkg
{
	ipk="$1"

	if ! check_dbg_pkg "$1"; then
		rm $ipk
	fi
}

function ipkgs
{
	if [ -d deploy/venus/ipk ]; then
		dst=$pkgs/$distro/
		echo "deploy/venus/ipk -> $dst"
		mkdir -p $pkgs
		cp -r deploy/venus/ipk $dst

		# remove unused packages
		find $dst -type d -name i686-nativesdk -prune -exec rm -rf {} \;
		find $dst -type d -name x86_64-nativesdk -prune -exec rm -rf {} \;

		# check packages
		find $dst -name "*-dbg_*.ipk" | while read ipk; do handle_dbg_pkg "$ipk"; done
		find $dst -name "*-src_*.ipk" | while read ipk; do handle_dbg_pkg "$ipk"; done
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

function suffix_symlinks
{
	ext="$1"
	suffix="$2"

	for symlink in $(find "$out" -type l -name "*.$ext"); do
		tg=$(readlink $symlink)

		# update where the symlink points to..
		ln -sfT "$tg.$suffix" $symlink
		# rename the symlink itself
		mv $symlink $symlink.$suffix
	done
}

function wic_images
{
	# gzip the wic files
	image venus-image wic
	suffix_symlinks "wic" "gz"
	find "$out" -type f -name "*.wic" -exec pigz {} \;
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
wic_images
image venus-upgrade-image zip
sdk

tar --use-compress-program=pigz -cf artifacts-$distro.tgz artifacts
