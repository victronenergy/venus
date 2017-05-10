#!/bin/bash

here=$(dirname $0)
host=$1
machine=$(ssh root@$host cat /etc/venus/machine)
cat $here/deploy/venus/images/$machine/venus-swu-$machine.swu | ssh root@$host /opt/victronenergy/swupdate-scripts/check-updates.sh -swu file:///dev/stdin

