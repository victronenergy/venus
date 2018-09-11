#!/bin/bash

here=$(dirname $0)
host=$1
if [ "$host" = "localhost" ]; then
        sshargs="-p4000 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet"
fi

machine=$(ssh $sshargs root@$host cat /etc/venus/machine)
cat $here/deploy/venus/images/$machine/venus-swu-$machine.swu | ssh $sshargs root@$host /opt/victronenergy/swupdate-scripts/check-updates.sh -swu file:///dev/stdin

