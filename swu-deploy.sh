set -eu

feed=develop
remote=victron_www@updates.victronenergy.com
remote_base=/var/www/victron_www/feeds/venus/swu/${feed}
machine=beaglebone
deploy=deploy/venus/images/${machine}
swu_link=venus-swu-${machine}.swu

swu_version=$(cat ${deploy}/${swu_link} | cpio --quiet -i --to-stdout sw-description 2>/dev/null |
        sed -n '/venus-version/ {
            s/.*"\(.*\)".*/\1/
            p
            q
        }')
echo "*** swu-deploy.sh - Deploying $swu_version"
echo "Checking if versions match ..."

swu_version=${swu_version%% *}

# TODO: doing this assumes that this is the rootfs that is in the latest swu file. Is
# that a safe assumption?
rootfs_version=$(tar -zxf $deploy/venus-image-${machine}.tar.gz ./opt/color-control/version -O | tail -n 1)

echo "* TODO: Add auto check if swu file is updateable (load in in target, set its version back, see what happens)?"

if [ "$swu_version" != "$rootfs_version" ]; then
    echo "Versions unequal!"
    echo "swu_version:    ${swu_version}"
    echo "rootfs_version: ${rootfs_version}"
    echo "Exit!"
    exit 1
fi

swu_full=venus-swu-${machine}-${swu_version}.swu
echo "* Uploading ${swu_full} ..."
rsync -cv ${deploy}/${swu_full} ${remote}:${remote_base}/

echo "* Creating deltas ..."
# For now abandoned attempt to create the deltas on the remote server:
# remote_tmp=$(ssh $remote "mktemp -d")
# echo "Using remote temp dir $remote_tmp"
# scp ./swu-make-delta.sh ${remote}:${remote_tmp}

files=$(ssh $remote "cd ${remote_base} && ls -t venus-swu-${machine}-*.swu | head -n 0")
for file in $files; do
    # Skip ourselves
    if [ "$file" = "${swu_full}" ]; then
        continue
    fi

    echo "* Processing remote file $file"

    if [ -e "${deploy}/${file}" ]; then
        ./swu-make-delta.sh ${deploy}/$file ${deploy}/${swu_full}
        deltafile="${swu_full::-4}-${file:(-18):-4}.tar.gz"
        echo "* Uploading delta file $deltafile to remote"
        rsync -cv ${deltafile} ${remote}:/$remote_base/
        rm ${deltafile}
    else
        echo "* skipping, file $file is no longer available"
    fi
done
echo "* Creating deltas completed"

echo "* Copying numbered file to ${swu_link} ..."
ssh $remote "cp ${remote_base}/venus-swu-${machine}-${swu_version}.swu ${remote_base}/${swu_link}"

echo "* Done!"
