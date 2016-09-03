#!/bin/bash
#
# Example:
# make-deltas.sh [old .swu file] [new .swu file]
#
# Output:
# - delta file (.tar.gz)

set -eu

. $(dirname $0)/sources/meta-victronenergy/meta-venus/recipes-support/swupdate-scripts/files/functions.sh

# take filename from paths
old=$(basename $1)
new=$(basename $2)

# make filename for the delta: imgname-[new build]-[old build]
delta=${old::-4}
delta=${new::-4}-${delta:(-14)}

uncompress_swu $1 .

if ! md5sum -c ${new}-uncompressed.md5; then
    uncompress_swu $2 .
    md5sum ${new}-uncompressed > ${new}-uncompressed.md5
fi

old=${old}-uncompressed
new=${new}-uncompressed

xdelta3 -fs $old $new $delta.xd3
md5sum $old > ${delta}.old.md5
md5sum $new > ${delta}.new.md5

tar -cvzf ${delta}.tar.gz ${delta}.*

# rm $delta.old.md5 $delta.xd3 $delta.new.md5 $old

