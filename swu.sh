#!/bin/bash

set -e

here=$(dirname $0)

update() {
	host=$1
	if [ "$host" = "localhost" ]; then
		sshargs="-p4000 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet"
	fi

	swu=$(ssh $sshargs root@$host cat /etc/venus/swu-name)
	machine=$(ssh $sshargs root@$host cat /etc/venus/machine)
	cat $here/deploy/venus/images/$machine/$swu-$machine.swu | ssh $sshargs root@$host /opt/victronenergy/swupdate-scripts/check-updates.sh -swu file:///dev/stdin
}

if [ "$#" -eq 0 ]; then
	echo "$0 host1 [host2 ...]"
	echo
	echo "Upload the latests build swu file to the host(s)."
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
