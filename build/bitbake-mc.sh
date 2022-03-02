#!/bin/sh

usage () {
	echo "usage: $0 [bitbake command]"
	echo
	echo "Wrapper to spawn bitbake for a multiconfig build."
	echo
	echo "Bitbake will be invoked for given command for every machine in BBMULTICONFIG."
	echo "You likely want to export BB_ENV_EXTRAWHITE='BBMULTICONFIG' so bitbake uses the same multiconfigs, e.g."
	echo
	echo "Instead of writing:"
	echo "  export BB_ENV_EXTRAWHITE='BBMULTICONFIG' BBMULTICONFIG='a b c'"
	echo "  bitbake mc:a:venus-swu mc:b:venus-swu mc:c:venus-swu"
	echo
	echo "The following can be used:"
        echo "  export BB_ENV_EXTRAWHITE='BBMULTICONFIG' BBMULTICONFIG='a b c'"
	echo "  ./bitbake-mc venus-swu"
	echo
	echo "So you no longer have to repeat all machines in the bitbake command."
	echo "Likewise '$0 -c cleanall target' will clean all multiconfigs."
	echo "Since the venus Makefiles know the machines, it allows commands like make-swus"
	echo "to build all swus in a single bitbake cooker with a simple command."
	echo
	echo "NOTE: -c is only option supported at the moment."
	echo "NOTE: this only works if the MACHINES are similiar."
}

while getopts "c:h" o; do
	case "$o" in
	c)
		args="$args -$o $OPTARG"
		;;
	h)
		usage
		exit
		;;
	*)
		echo unknown argument
		exit 1
		;;
	esac
done
shift $((OPTIND-1))

if [ -z "$BBMULTICONFIG" ]; then
	echo "ERROR: BBMULTICONFIG is not set"
	echo "^------------------------------"
	usage
	exit 1
fi

if ! which bitbake >/dev/null; then
	echo "ERROR: no bitbake available"
	echo "NOTE: you need to source the oe init build script"
	echo "^------------------------------------------------"
	usage
	exit 1
fi

recipes="$@"
for recipe in $recipes; do
	for machine in $BBMULTICONFIG; do
		args="$args mc:$machine:$recipe"
	done
done

exec bitbake $args
