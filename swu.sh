#!/bin/bash

set -e

here=$(dirname $0)
type=""

update() {
	host=$1
	if [ "$host" = "localhost" ]; then
		sshargs="-p4000 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet"
	fi

	if [ -z "$type" ]; then
		type=$(ssh $sshargs root@$host 'if [ -f /etc/venus/image-type ]; then head -n1 /etc/venus/image-type; else echo -n normal; fi')
	fi

	case "$type" in
	"normal")
		type_suffix=""
		;;
	*)
		type_suffix="-$type"
		;;
	esac

	swu_name=$(ssh $sshargs root@$host cat /etc/venus/swu-name)
	machine=$(ssh $sshargs root@$host cat /etc/venus/machine)
	swu_file="$swu_name$type_suffix-$machine.swu"

	if [ ! -e $here/deploy/venus/images/$machine/$swu_file ]; then
		echo "ERROR: the file doesn't exist: $swu_file. Use -t [normal|large] to force image type."
		exit 1
	fi

	# Warn if the swu file being uploaded is not the one most recently build..
	latest=$(find deploy -type f -regextype posix-egrep -regex '.*-[0-9]+-[^-]+\.swu$' | sed -E 's/.*-([0-9]+)-[^-]+\.swu$/\1/g' | sort -rn | head -n1)
	swu_stamp=$(find deploy/ -name "$swu_file" -exec readlink {} \; | sed -E 's/.*-([0-9]+)-[^-]+\.swu$/\1/g')
	if [ "$latest" != "$swu_stamp" ]; then
		echo "WARNING: not uploading the latest build!"
	fi

	cat $here/deploy/venus/images/$machine/$swu_file | ssh $sshargs root@$host /opt/victronenergy/swupdate-scripts/check-updates.sh -swu file:///dev/stdin
}

while getopts "t:" o; do
	case "$o" in
	t)
		case "${OPTARG}" in
		"normal")
			type="normal"
			;;
		"large")
			type="large"
			;;
		*)
			echo "invalid image type: ${OPTARG}"
			exit 1
			;;
		esac
	esac
done
shift $(expr $OPTIND - 1 )

if [ "$#" -eq 0 ]; then
	echo "$0 [-t normal|large] host1 [host2 ...]"
	echo
	echo "Upload the latests build swu file to the host(s)."
	echo
	echo "-t normal| large"
	echo "     The image type to be installed, by default the same image type will be"
	echo "     installed on the target as already installed; the user setting is ignored."
	echo
	echo "Note: with multiple hosts the output is a complete mess."
	exit
fi

while (( "$#" ));
do
	update $1 &
	shift
done

wait
