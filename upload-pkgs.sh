#!/bin/sh

for buildoutput in deploy/*; do
	for upload in $buildoutput/upload-*; do
		local=${upload//upload-/}
		remote=`head -n1 $upload`
		if [ $? -ne 0 ] || [ -z "$remote" ]; then
			echo "skipping $local, not remote"
			continue
		fi
		if [ ! -d $local ]; then
			echo "skipping $local, not a dir"
			continue
		fi
		# -delete-excluded --delete
		echo "$local -> $remote"
		rsync -v -rp -e ssh $local victron_www@updates.victronenergy.com:/var/www/victron_www/feeds/$remote
	done
done
